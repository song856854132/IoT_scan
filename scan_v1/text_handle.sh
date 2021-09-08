#!/bin/bash
for file in $1; do
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
                base64 -di temp4 > $2
                rm temp*
        else
                #print error info incase input is not a file
                echo "$file is not a file, please specify a file." >&2 && exit 1
        fi
done
#terminate script with exit code 0 in case of successful execution 
exit 0