#! /bin/bash

if [ -z "$@" ]
then
        echo "Usage: ./scan.sh <IP> <BurpSuite History>" # input IP and header file, output recon_result
        exit 1
fi

rm recon_results
#START_TIME="$(date +%s)"
#printf "\n----- NMAP -----\n\n" > recon_results 

echo "Running Nmap..."
#nmap -sC -sS -Pn -T4 -sV -A $1  > temp0 
#printf "Section5 網路服務最小化測試" > temp01
#nmap -sT -p 0-65535 -O -A -vv -sC $1 > temp01
#nmap -sU -p 0-65535 -O -A -vv -sC $1 > temp02


echo "Running Nikto..."
#printf "Section6 網頁管理介面安全" > temp1
#nikto -h $1  >> temp1 

#wait
#END_TIME="$(date +%s)"
#echo "executing time... $[ ${END_TIME} - ${START_TIME} ]"


# Readline HTTP Header from Burp Suite 
while read line
do
        # HTTP Authenticaiton checking
        if [[ $line == Authorization:* ]] || [[ $line == *api_key=* ]] || [[ $line == X-API-Key:* ]]
        then
                #Section7 網頁管理介面安全 - 使用者認證:
                echo $line >> temp21
        fi

        # HTTP Cookie checking
        if [[ $line == Cookie:* ]]
        then
                #Section8 網頁管理介面安全 - Cookie
                echo $line >> temp22
                
        fi

        # HTTP dir fuzzing 
        if [[ $line == *open* ]] && [[ $line == *http* ]]
        then
                echo $line >> temp23
                http_open_counter+=1
        fi

        # XSS proteciton
        if [[ $line == X-XSS* ]]
        then
                #Section8 網頁管理介面安全 - XSS
                echo $line >> temp24
                
        fi
done < $2

if [[ http_open_counter ]]
then
        # Section10 網頁管理介面安全 - 邏輯漏洞
        echo "Running Dirb..."
        dirb http://$1 /usr/share/wordlists/dirb/common.txt  > temp31

        echo "Running WhatWeb..."
        whatweb $1 -v > temp32
fi
# Section11 網頁管理介面安全 - 輸入驗證(Injeciton Testing)
owasp-zap -cmd -quickurl http://192.168.0.1:80/ -quickprogress > temp41 ## alert
#xsser 
#sqlmap
# Section12 應用程式 - HTTP(S)安全測試
sslscan $1 > temp5

# Section13 應用程式 - UPnP安全測試
sudo nmap -sU --script=upnp-info.nse -p 1900 $1 > temp6

# Section14 應用程式 - DNS安全測試
nslookup -debug -class=CH -query=TXT version.bind $1 > temp7

if [[ -e temp0 ]] || [[ -e temp01 ]] || [[ -e temp02 ]]
then
        printf "Section5 網路服務最小化測試\n" >> recon_results
        cat temp0  >> recon_results

        printf "Section5 網路服務最小化測試 -- TCP\n" >> recon_results
        cat temp01  >> recon_results
        printf "Section5 網路服務最小化測試 -- UDP\n" >> recon_results
        cat temp02  >> recon_results
fi

if [ -e temp1 ]
then
        printf "\nSection6 網頁管理介面安全\n" >> recon_results
        cat temp1  >> recon_results
fi

if [ -e temp21 ]
then
        printf "\nSection7 網頁管理介面安全 - 使用者認證\n" >> recon_results
        cat temp21 >> recon_results
else
        printf "Section7 網頁管理介面安全 - 使用者認證 Fail -- No Authorization Found\n" >> recon_results
fi

if [ -e temp22 ]
then
        printf "\nSection7 網頁管理介面安全 - Cookie\n" >> recon_results
        cat temp22 >> recon_results
fi

if [ -e temp23 ]
then
        printf "\nSection7 網頁管理介面安全 - HTTP\n" >> recon_results
        cat temp23 >> recon_results
fi

if [ -e temp24 ]
then
        printf "\nSection7 網頁管理介面安全 - XSS injection\n" >> recon_results
        cat temp24 >> recon_results
fi

if [ -e temp31 ]
then
        printf "\nSection10 網頁管理介面安全 - 邏輯漏洞\n" >> recon_results
        cat temp31 >> recon_results
fi

if [ -e temp32 ]
then
        cat temp32 >> recon_results
fi

if [ -e temp41 ]
then
        printf "\nSectionSection11 網頁管理介面安全 - 輸入驗證(Injeciton Testing)\n" >> recon_results
        cat temp41 >> recon_results
fi

if [ -e temp5 ]
then
        printf "\nSection12 應用程式 - HTTP(S)安全測試\n" >> recon_results
        cat temp5 >> recon_results
fi

if [ -e temp6 ]
then
        printf "\nSection13 應用程式 - UPnP安全測試\n" >> recon_results
        cat temp6 >> recon_results
fi

if [ -e temp7 ]
then
        printf "\nSection14 應用程式 - DNS安全測試\n" >> recon_results
        cat temp7 >> recon_results
fi

rm temp*
exit 0
