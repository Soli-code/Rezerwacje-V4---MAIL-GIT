curl -X POST "https://klumxecllfauamqnrckf.supabase.co/functions/v1/send-email-template" ^
-H "Content-Type: application/json" ^
-H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsdW14ZWNsbGZhdWFtcW5yY2tmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTY0NzI3NSwiZXhwIjoyMDU3MjIzMjc1fQ.24k0Ssu_Gve-lqgN4HOlcqhvKYY_njvs3oz6Xkl5N_o" ^
-d @test-email-status.json
pause 