# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "google-genai",
#     "python-dotenv",
#     "rich",
# ]
# ///
import os
from dotenv import load_dotenv
import argparse
import sys
import time
from google import genai
from google.genai import types
from rich.console import Console
from rich.panel import Panel

console = Console()


load_dotenv()

def get_client():
    api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        console.print("[bold red]Error:[/bold red] GOOGLE_API_KEY or GEMINI_API_KEY environment variable is required.")
        sys.exit(1)
    
    # Force vertexai=False to use the Gemini Developer API (AI Studio)
    # which supports Interactions and File API with API Keys.
    return genai.Client(api_key=api_key, vertexai=False)

def main():
    parser = argparse.ArgumentParser(description="Run Gemini Deep Research Agent.")
    parser.add_argument("prompt", help="The research goal/question.")
    parser.add_argument("--file", help="Path to a local file or directory for context.", action="append")
    parser.add_argument("--stream", action="store_true", help="Stream thoughts and progress.", default=True)
    parser.add_argument("--no-thoughts", action="store_true", help="Hide thinking process.")
    parser.add_argument("--output", help="Save the final report to this file.")
    parser.add_argument("--follow-up", help="Interaction ID to continue.")
    parser.add_argument("--use-file-store", action="store_true", help="Use File Search Store (RAG) instead of direct context. Better for large corpora.")
    
    args = parser.parse_args()
    client = get_client()
    
    # 1. Prepare Input & Tools
    input_content = []
    tools = None
    
    # Text Prompt is always needed
    input_content.append({"type": "text", "text": args.prompt})
    
    # Handle Files
    if args.file:
        files_to_upload_paths = []
        for path in args.file:
            if os.path.isfile(path):
                files_to_upload_paths.append(path)
            elif os.path.isdir(path):
                for root, _, files in os.walk(path):
                    for file in files:
                        if file.lower().endswith(('.txt', '.md', '.pdf', '.html', '.csv', '.py', '.js', '.ts', '.json')):
                            files_to_upload_paths.append(os.path.join(root, file))
            else:
                console.print(f"[bold red]Error:[/bold red] Path not found: {path}")
                sys.exit(1)

        if not files_to_upload_paths:
             console.print(f"[yellow]Warning:[/yellow] No supported files found.")
        
        elif args.use_file_store:
            # Mode: File Search Store (RAG)
            console.print("[blue]Creating File Search Store...[/blue]")
            store = client.file_search_stores.create()
            console.print(f"[dim]Store created: {store.name}[/dim]")
            
            for fpath in files_to_upload_paths:
                console.print(f"[dim]Uploading to store: {fpath}[/dim]")
                try:
                    # Upload directly to store (efficient)
                    client.file_search_stores.upload_to_file_search_store(
                        file=fpath,
                        file_search_store_name=store.name
                    )
                except Exception as e:
                    console.print(f"[bold red]Upload failed for {fpath}:[/bold red] {e}")
            
            # Wait for indexing (simple check, or rely on API to handle pending)
            console.print("[blue]Files uploaded. Configuring agent...[/blue]")
            
            tools = [{
                "file_search": {
                    "file_search_store_names": [store.name]
                }
            }]
            
        else:
            # Mode: Direct Context (Reading)
            for fpath in files_to_upload_paths:
                console.print(f"[dim]Uploading {fpath}...[/dim]")
                try:
                    file_obj = client.files.upload(file=fpath)
                    console.print(f"[dim]Uploaded: {file_obj.uri}[/dim]")
                    
                    if file_obj.mime_type.startswith("image/"):
                        ctype = "image"
                    else:
                        ctype = "document"
                        
                    input_content.append({"type": ctype, "uri": file_obj.uri, "mime_type": file_obj.mime_type})
                except Exception as e:
                    console.print(f"[bold red]Upload failed for {fpath}:[/bold red] {e}")

    agent_config = {
        "type": "deep-research",
        "thinking_summaries": "auto"
    }

    # 2. Start Research (Resilient Loop)
    interaction_id = args.follow_up
    last_event_id = None
    is_complete = False
    full_text = ""
    
    console.print(Panel(f"[bold blue]Starting Deep Research[/bold blue] Target: {args.prompt}", border_style="blue"))

    try:
        # Initial Request
        create_kwargs = {
            "agent": "deep-research-pro-preview-12-2025",
            "background": True,
            "stream": args.stream,
            "agent_config": agent_config,
        }
        
        if interaction_id:
             create_kwargs["input"] = input_content if len(input_content) > 1 else args.prompt
             create_kwargs["previous_interaction_id"] = interaction_id
             # Tools are interaction-scoped, so if we added a store, we must pass it again?
             # Actually, if we are continuing, we might want to keep the store.
             # But usually follow-ups are text-based clarifications.
             # If --use-file-store was passed *again*, we add it.
             if tools:
                 create_kwargs["tools"] = tools
        else:
            create_kwargs["input"] = input_content if len(input_content) > 1 else input_content[0]
            if tools:
                create_kwargs["tools"] = tools

        stream = client.interactions.create(**create_kwargs)
            
        # Process the stream with resilience
        while not is_complete:
            try:
                for chunk in stream:
                    # Capture ID
                    if chunk.event_type == "interaction.start":
                        interaction_id = chunk.interaction.id
                        console.print(f"[dim]Interaction ID: {interaction_id}[/dim]")
                    
                    if chunk.event_id:
                        last_event_id = chunk.event_id

                    # Handle Content
                    if chunk.event_type == "content.delta":
                        if chunk.delta.type == "text":
                            # Final report text
                            text_delta = chunk.delta.text
                            full_text += text_delta
                            console.print(text_delta, end="")
                        elif chunk.delta.type == "thought_summary" and not args.no_thoughts:
                            # Agent thoughts
                            thought = chunk.delta.content.text
                            console.print(f"\n[bold yellow]Thinking:[/bold yellow] {thought}")
                    
                    elif chunk.event_type == "interaction.complete":
                        is_complete = True
                        console.print("\n[bold green]Research Complete[/bold green]")
                        break
                        
                    elif chunk.event_type == "error":
                        console.print(f"\n[bold red]API Error:[/bold red] {chunk.error.message}")
                        is_complete = True
                        break
                
                if is_complete: 
                    break

            except Exception as e:
                console.print(f"\n[bold red]Connection dropped:[/bold red] {e}")
                if not interaction_id:
                    # If we failed before getting an ID, we can't resume.
                    sys.exit(1)
                
                console.print("[yellow]Attempting to resume stream...[/yellow]")
                time.sleep(2)
                
                # Resume using GET
                stream = client.interactions.get(
                    id=interaction_id,
                    stream=True,
                    last_event_id=last_event_id
                )

    except Exception as e:
        console.print(f"[bold red]Fatal Error:[/bold red] {e}")
        sys.exit(1)

    # 3. Save Output
    if args.output and full_text:
        with open(args.output, "w") as f:
            f.write(full_text)
        console.print(f"[dim]Report saved to {args.output}[/dim]")

if __name__ == "__main__":
    main()
