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
    const { name, email, instagram, concept, placement, website_url } = body;

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
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <style>
    :root {
      color-scheme: light dark;
      supported-color-schemes: light dark;
    }
    body {
      background-color: #0A0A0C !important;
      color: #EBEBE6 !important;
      margin: 0;
      padding: 0;
    }
    .email-container {
      background-color: #0A0A0C !important;
    }
  </style>
</head>
<body style="background-color: #0A0A0C; padding: 40px 20px; font-family: Helvetica, Arial, sans-serif; color: #EBEBE6; text-align: center; margin: 0;">
  <div class="email-container" style="max-width: 600px; margin: 0 auto; border: 1px solid #8A1E1E; padding: 40px; background-color: #0A0A0C;">
    
    <img src="https://brkntattoos.com/images/logo.png" alt="BRKN Tattoos" style="width: 120px; margin-bottom: 30px;" />
    
    <h1 style="text-transform: uppercase; letter-spacing: 2px; font-weight: normal; font-size: 20px; border-bottom: 1px solid #333333; padding-bottom: 20px; margin-bottom: 30px; color: #EBEBE6;">
      Initiation Received
    </h1>
    
    <p style="line-height: 1.8; letter-spacing: 1px; font-size: 14px; color: #EBEBE6;">
      Thank you for inquiring to work together. I will review your design and reach out for the next steps.
    </p>
    
    <p style="margin-top: 40px; text-transform: uppercase; letter-spacing: 3px; color: #8A1E1E; font-size: 12px;">
      Welcome to the underground.
    </p>
    
    <p style="margin-top: 10px; letter-spacing: 2px; font-size: 12px; color: #a1a19b;">
      - Mr BRKN
    </p>

  </div>
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
