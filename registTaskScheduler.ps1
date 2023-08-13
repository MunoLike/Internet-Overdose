$user_id = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$xml = [xml](Get-Content .\task.xml)
$xml.Task.Principals.Principal.UserId = $user_id

Register-ScheduledTask -Force -Xml $xml.OuterXml -TaskPath "\InternetOverdose\" -TaskName "Start wstunnel"