1..255 | 
    ForEach-Object {
    "192.168.2.$_"
    } |
    ForEach-Object {
        Test-RemotePort -ComputerName $_ -Port 9100 -TimeoutMilliSec 500        
    } |
    Select-Object -Property ComputerName, Port, Response
