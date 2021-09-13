#! /bin/bash

# banner
echo "
 ___    _____   ____                  
|_ _|__|_   _| / ___|  ___ __ _ _ __  
 | |/ _ \| |   \___ \ / __/ _\` | '_ \ 
 | | (_) | |    ___) | (_| (_| | | | |
|___\___/|_|___|____/ \___\__,_|_| |_|
          |_____|                     "


if [ -z "$@" ];
then
    echo "Welcome to IoT_scan, please input burp packet file and IP"
    # input source file and IP
    echo "Burp raw file:"
    read -r burp_raw

    echo "IP address:"
    read -r ip_addr
else 
    burp_raw=$1 
    ip_addr=$2 
fi
# Decode raw burp packet 
for file in $burp_raw; do
    burp_decode=$(echo $burp_raw|sed 's/raw/decode/g')
    #echo $burp_decode
    if [ -f $file ] ; then
        #print out filename
        echo "File is: $file"
        #print the total number of times tecmint.com appears in the file
        awk '
              /<request base64="true"><!\[CDATA/, /\]><\/request>/ { req_counter+=1; print;}
              /<response base64="true"><!\[CDATA/, /\]><\/response>/ { resp_counter+=1; print;}
              
            '  $file > temp0
        sed 's/<request base64="true"><!\[CDATA\[//' temp0 > temp1 
        sed 's/\]\]><\/request>//' temp1 > temp2
        sed 's/<response base64="true"><!\[CDATA\[//' temp2 > temp3
        sed 's/\]\]><\/response>/\n/' temp3 > temp4
        
        # echo "$req_counter req and $resp_counter resp"
        base64 -di temp4 > $burp_decode
        rm temp*
    else
        #print error info incase input is not a file
        echo "$file is not a file, please specify a file." >&2 && exit 1
    fi
done

rm Section*
rm recon_results
# Section5 網路服務最小化測試
# Section13 應用程式 - UPnP安全測試
NMAP()
{
    echo "Running Nmap..."
    timeout 600 nmap -sT -p 0-65535 -O -A -sC $ip_addr >  Section5_TCP
    timeout 600 nmap -sU -p 0-65535 -O -A -sC $ip_addr > Section5_UDP
    timeout 600 nmap -sU --script=upnp-info.nse -p 1900 $ip_addr > Section13_UPnP
}

# Section6 網頁管理介面安全
NIKTO()
{
    echo "Running Nikto..."
    nikto -h $ip_addr | tee Section6
}
# Section7 網頁管理介面安全 - 使用者認證 
# Section8 網頁管理介面安全 - 連線管理 Burp Suite -- Cookie
# Section9 網頁管理介面安全 - 使用者授權 Burp Suite -- Cookie
echo "Readline HTTP Header from Burp Suite..."
while read line 
do
    # HTTP Authenticaiton checking
    if [[ $line == Authorization:* ]] || [[ $line == *api_key=* ]] || [[ $line == X-API-Key:* ]]
    then
        # Section7 網頁管理介面安全 - 使用者認證
        echo $line > Section7_AUTH
    fi

    # HTTP Cookie checking
    if [[ $line == Cookie:* ]]
    then
        # Section8 網頁管理介面安全 - 連線管理Cookie
        echo $line >> Section8_COOKIE
        
    fi

    # HTTP dir fuzzing probe
    if [[ $line == *open* ]] && [[ $line == *http* ]]
    then
        echo $line >> Section10
        http_open_counter+=1
    fi

    # XSS proteciton
    if [[ $line == X-XSS* ]]
    then
        # Section11 網頁管理介面安全 - 輸入驗證
        echo $line >> Section11
        
    fi
done < $burp_decode
# Section10 網頁管理介面安全 - 邏輯漏洞
WEB_FUZZ()
{
    read -r -p "Does it support https(SSL)? [Y/n]: " yn_ssl
    echo "Running Dirbuster..."
    case $yn_xss in 
        [Yy]*) gobuster dir -u https://$ip_addr -w /usr/share/wordlists/dirb/common.txt | tee Section10_DIR;;
        [Nn]*) gobuster dir -u http://$ip_addr -w /usr/share/wordlists/dirb/common.txt | tee Section10_DIR;;
    esac
    echo "Running WhatWeb..."
    case $yn_xss in 
        [Yy]*) whatweb https://$ip_addr -v | tee Section10_WEB;;
        [Nn]*) whatweb http://$ip_addr -v | tee Section10_WEB;;
    esac
    whatweb $ip_addr -v > Section10_WEB
}
# Section11 網頁管理介面安全 - 輸入驗證 ZAP, XSSer, SQLmap
XSSER()
{
    echo "Running Xsser..."
    xsser --wizard | tee Section11_XSS
}
SQLMAP()
{
    echo "Running Sqlmap..."
    sqlmap --wizard | tee Section11_SQL
}
# Section12 應用程式 - HTTP(S)安全測試
SSLSCAN()
{
    echo "Running Sslscan..."
    sslscan $ip_addr | tee Section12
}
# Section14 應用程式 - DNS安全測試
DNS()
{
    echo "Running Nslookup..."
    nslookup -debug -class=CH -query=TXT version.bind $ip_addr > Section14
}

# Section16 韌體靜態檢測
BIN()
{
    echo "Running Binewalk..."
    binwalk -Me $1 > Section16 
}

# Execute and Write into Test Rreport
NMAP
if [[ -e Section5_TCP ]] || [[ -e Section5_UDP ]]
then
        printf "\nSection5 網路服務最小化測試\n" >> recon_results
        cat Section5_TCP  >> recon_results
        cat Section5_UDP  >> recon_results
fi
NIKTO
if [[ -e Section6 ]]
then
        printf "\nSection6 網頁管理介面安全\n" >> recon_results
        cat Section6  >> recon_results
fi
if [[ -e Section7_AUTH ]]
then
        printf "\nSection7 網頁管理介面安全 - 使用者認證Authorization\n" >> recon_results
        cat Section7_AUTH  >> recon_results
fi
if [[ -e Section8_COOKIE ]]
then
        printf "\n# Section8 網頁管理介面安全 - 連線管理Cookie\n" >> recon_results
        cat Section8_COOKIE  >> recon_results
fi
if [[ http_open_counter ]]
then
    WEB_FUZZ
    if [[ -e Section10_DIR ]] || [[ -e Section10_WEB ]]
    then
            printf "\nSection10 網頁管理介面安全 - 邏輯漏洞Fuzz\n" >> recon_results
            cat Section10_DIR  >> recon_results
            cat Section10_WEB  >> recon_results
    fi
fi
if [[ -e Section11 ]]
then
        printf "\nSection11 網頁管理介面安全 - 輸入驗證\n" >> recon_results
        cat Section11  >> recon_results
fi
read -r -p "Do you want to execute XSS attack? [Y/n]: " yn_xss
case $yn_xss in 
        [Yy]*) XSSER;;
        [Nn]*) echo "Okay, then";;
esac
if [[ -e Section11_XSS ]]
then
        #iprintf "\nSection11 網頁管理介面安全 - 輸入驗證\n" >> recon_results
        cat Section11_XSS  >> recon_results
fi
if [[ -e Section11_SQL ]]
then
        #printf "\nSection11 網頁管理介面安全 - 輸入驗證\n" >> recon_results
        cat Section11_SQL  >> recon_results
fi
read -r -p "Do you want to execute SQL injection? [Y/n]: " yn_sql
case $yn_sql in 
        [Yy]*) SQLMAP;;
        [Nn]*) echo "Okay, then";;
esac
SSLSCAN
DNS
read -r -p "Do you want to execute firmware testing? [Y/n]: " yn_sql
case $yn_sql in 
        [Yy]*) read -r -p "testing bin file: " binfile; BIN $binfile;;
        [Nn]*) echo "Okay, then";;
esac
rm Section*
