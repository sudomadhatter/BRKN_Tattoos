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
    // The card is a pre-rendered image so phone dark mode CANNOT invert it —
    // email clients never recolor image content. A plain-text fallback covers
    // clients that block images.
    const { error: replyError } = await resend.emails.send({
      from: 'BRKN Tattoos <booking@brkntattoos.com>',
      to: [email],
      subject: "Initiation Received",
      text: `Initiation Received

Thank you for inquiring to work together. I will review your design and reach out for the next steps.

Welcome to the underground.
- Mr BRKN`,
      html: `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
</head>
<body bgcolor="#0A0A0C" style="background-color: #0A0A0C; margin: 0; padding: 0;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0A0A0C" style="background-color: #0A0A0C;">
    <tr>
      <td align="center" bgcolor="#0A0A0C" style="background-color: #0A0A0C; padding: 40px 20px;">
        <!-- Fixed image of the confirmation card. Baked-in colors are immune to dark/light mode. -->
        <img
          src="https://brkntattoos.com/images/email-confirmation.png"
          width="600"
          alt="Initiation Received. Thank you for inquiring to work together. I will review your design and reach out for the next steps. Welcome to the underground. - Mr BRKN"
          style="width: 100%; max-width: 600px; height: auto; display: block; border: 0;"
        />
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
