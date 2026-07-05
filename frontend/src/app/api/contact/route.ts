import { NextResponse } from 'next/server';
import { Resend } from 'resend';

// Only initialize Resend if the API key exists
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

export async function POST(req: Request) {
  try {
    if (!resend) {
      console.warn("RESEND_API_KEY is not set. Simulating a successful email send.");
      // Return a fake success if they haven't set up the API key yet
      return NextResponse.json({ success: true, message: "Email simulated successfully (API key missing)" });
    }

    const body = await req.json();
    const { name, email, instagram, concept, placement } = body;

    // Validate required fields
    if (!name || !email || !concept || !placement) {
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    const { data, error } = await resend.emails.send({
      from: 'BRKN Tattoos Booking <booking@brkntattoos.com>', // User needs to verify this domain in Resend
      to: ['noah.brkntattoos@gmail.com'], // Deliver all bookings to this Gmail inbox
      subject: `New Booking Request: ${name}`,
      replyTo: email,
      html: `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
          <h1 style="color: #000; border-bottom: 2px solid #000; padding-bottom: 10px;">New Booking Request</h1>
          
          <div style="margin-top: 20px;">
            <p><strong>Name:</strong> ${name}</p>
            <p><strong>Email:</strong> <a href="mailto:${email}">${email}</a></p>
            <p><strong>Instagram:</strong> ${instagram || 'Not provided'}</p>
          </div>

          <div style="margin-top: 20px; background-color: #f5f5f5; padding: 15px; border-radius: 5px;">
            <h2 style="margin-top: 0;">Tattoo Details</h2>
            <p><strong>Placement:</strong> ${placement}</p>
          </div>

          <div style="margin-top: 20px;">
            <h3>Concept Description</h3>
            <p style="white-space: pre-wrap;">${concept}</p>
          </div>
        </div>
      `,
    });

    if (error) {
      console.error("Resend Error:", error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data });
  } catch (error) {
    console.error("Server Error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
