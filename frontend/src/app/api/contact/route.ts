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
    const { name, email, phone, concept, placement, website_url, attachments } = body;

    // Normalize + cap client-supplied image attachments (base64, no data-URL prefix).
    const safeAttachments = Array.isArray(attachments)
      ? attachments
          .filter((a) => a && typeof a.filename === 'string' && typeof a.content === 'string')
          .slice(0, 4)
          .map((a) => ({ filename: a.filename, content: a.content }))
      : [];

    // --- HONEYPOT SPAM PROTECTION ---
    // If a bot fills out the hidden 'website_url' field, silently succeed without sending an email.
    if (website_url && website_url.trim() !== '') {
      console.log('Spam bot detected and rejected silently.');
      return NextResponse.json({ success: true, message: "Request received" });
    }

    // Validate required fields
    if (!name || !email || !concept || !placement) {
      return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
    }

    const { data, error } = await resend.emails.send({
      from: 'BRKN Tattoos Booking <booking@brkntattoos.com>', // User needs to verify this domain in Resend
      to: ['noah.brkntattoos@gmail.com'], // Deliver all bookings to this Gmail inbox
      subject: `New Booking Request: ${name}`,
      replyTo: email,
      attachments: safeAttachments.length > 0 ? safeAttachments : undefined,
      html: `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #333;">
          <h1 style="color: #000; border-bottom: 2px solid #000; padding-bottom: 10px;">New Booking Request</h1>
          
          <div style="margin-top: 20px;">
            <p><strong>Name:</strong> ${name}</p>
            <p><strong>Email:</strong> <a href="mailto:${email}">${email}</a></p>
            <p><strong>Phone:</strong> ${phone || 'Not provided'}</p>
            ${safeAttachments.length > 0 ? `<p><strong>Reference Images:</strong> ${safeAttachments.length} attached</p>` : ''}
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

    // --- SECONDARY AUTO-REPLY TO CLIENT ---
    const { error: replyError } = await resend.emails.send({
      from: 'BRKN Tattoos <booking@brkntattoos.com>',
      to: [email],
      subject: "Initiation Received",
      html: `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <!-- Declare dark-scheme support so iOS Mail / Gmail leave our palette alone instead of auto-transforming it -->
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <style>
    :root {
      color-scheme: dark;
      supported-color-schemes: dark;
    }
    /* Gmail dark-mode transform overrides — force our fixed colors back */
    u + .body .dm-bg,
    [data-ogsb] .dm-bg,
    [data-ogsc] .dm-bg { background-color: #0A0A0C !important; }
    [data-ogsc] .dm-text { color: #EBEBE6 !important; }
    [data-ogsc] .dm-blood { color: #8A1E1E !important; }
    [data-ogsc] .dm-muted { color: #a1a19b !important; }
  </style>
</head>
<body class="body" bgcolor="#0A0A0C" style="background-color: #0A0A0C; margin: 0; padding: 0;">
  <!-- Outer table locks the page background via the bgcolor attribute (respected even when CSS is overridden) -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0A0A0C" class="dm-bg" style="background-color: #0A0A0C;">
    <tr>
      <td align="center" style="padding: 40px 20px;">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="#0A0A0C" class="dm-bg" style="max-width: 600px; width: 100%; background-color: #0A0A0C; border: 1px solid #8A1E1E;">
          <tr>
            <td align="center" bgcolor="#0A0A0C" class="dm-bg" style="background-color: #0A0A0C; padding: 40px; font-family: Helvetica, Arial, sans-serif; text-align: center;">

              <img src="https://brkntattoos.com/images/logo.png" alt="BRKN Tattoos" width="120" style="width: 120px; margin-bottom: 30px; opacity: 0.9;" />

              <h1 class="dm-text" style="text-transform: uppercase; letter-spacing: 2px; font-weight: normal; font-size: 20px; border-bottom: 1px solid #333333; padding-bottom: 20px; margin: 0 0 30px 0; color: #EBEBE6;">
                Initiation Received
              </h1>

              <p class="dm-text" style="line-height: 1.8; letter-spacing: 1px; font-size: 14px; margin: 0; color: #EBEBE6;">
                Thank you for inquiring to work together. I will review your design and reach out for the next steps.
              </p>

              <p class="dm-blood" style="margin: 40px 0 0 0; text-transform: uppercase; letter-spacing: 3px; color: #8A1E1E; font-size: 12px;">
                Welcome to the underground.
              </p>

              <p class="dm-muted" style="margin: 10px 0 0 0; letter-spacing: 2px; font-size: 12px; color: #a1a19b;">
                - Mr BRKN
              </p>

            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
      `,
    });

    if (replyError) {
      console.error("Auto-reply Error:", replyError);
    }


    return NextResponse.json({ success: true, data });
  } catch (error) {
    console.error("Server Error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
