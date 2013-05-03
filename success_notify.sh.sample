#!/bin/bash                                 
                                            
[ $# -lt 1 ] && exit 2                      
                                            
MESSAGE="$1"
MESSAGE=$(echo -e $MESSAGE)

APP_TOKEN="your-app-token-here"
USER_KEYS=(
          'user-key-here'
        # 'other-user-keys-here'
          )
                                            
# I use -k directive here as non-cert for pushover
for USER_KEY in "${USER_KEYS[@]}"
do
   curl -sk \
     -F "token=${APP_TOKEN}" \
     -F "user=${USER_KEY}" \
     -F "message=${MESSAGE}" \
     https://api.pushover.net/1/messages
done
                                            

