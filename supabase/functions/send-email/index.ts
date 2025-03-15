import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log('Function starting...')

serve(async (req) => {
  console.log('Request received')
  console.log('Request method:', req.method)
  console.log('Request headers:', Object.fromEntries(req.headers.entries()))
  
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    console.log('Handling OPTIONS request')
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // Validate authorization header
    const authHeader = req.headers.get("authorization");
    console.log('Auth header:', authHeader)
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      console.error('Unauthorized')
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Parse request body
    const requestData = await req.json();
    console.log("Received request data:", JSON.stringify(requestData, null, 2));
    
    // Validate required fields
    const requiredFields = ["recipientEmail", "templateId", "templateData"];
    for (const field of requiredFields) {
      if (!requestData[field]) {
        console.error(`Missing required field: ${field}`)
        return new Response(JSON.stringify({ error: `Missing required field: ${field}` }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch email template from Supabase
    const { data: template, error: templateError } = await supabase
      .from('email_templates')
      .select('*')
      .eq('id', requestData.templateId)
      .single();

    if (templateError || !template) {
      console.error('Template error:', templateError);
      throw new Error('Email template not found');
    }

    // Replace template variables with actual data
    let htmlContent = template.html_content;
    for (const [key, value] of Object.entries(requestData.templateData)) {
      htmlContent = htmlContent.replace(new RegExp(`{{${key}}}`, 'g'), String(value));
    }

    console.log("Sending email via Resend...");

    // Send email using Resend API
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer re_XsXzFXCn_HfPK82Y9Cc8NdSLu9ysE46C4`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `SOLRENT Rezerwacje <biuro@solrent.pl>`,
        to: requestData.recipientEmail,
        subject: template.subject,
        html: htmlContent,
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      console.error("Resend API error:", error);
      throw new Error(error.message || "Failed to send email via Resend");
    }

    console.log("Email sent successfully");

    return new Response(JSON.stringify({ message: "Email sent successfully" }), {
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });

  } catch (error) {
    console.error("Error sending email:", error);
    return new Response(JSON.stringify({ error: `Failed to send email: ${error.message}` }), {
      status: 500,
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
}) 