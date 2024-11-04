# ============================================================================ #
#                           DB CONNECTION SCRIPT                               #
#                                                                              #
#                                Colin Mclean                                  #
#                            Colin.D.Mclean@ed.ac.uk                           #
#                                 08-09-2024                                   #
#                                                                              #
#             THIS SCRIPT DEPENDS ON YOU ENTERING YOUR                         #
#             DB CREDENTIALS USING THE KEYRING R PACKAGE                       #
#             ## install.packages(c("keyring","usethis"))                      #
#                                                                              #
#             library(usethis)                                                 #
#             library(keyring)                                                 #
#                                                                              #
#             EDIT .RENVIRON FILE TO ADD YOUR KEYRING DETAILS                  # 
#             > edit_r_environ()                                               #
#             > MY_KEYRING_NAME="..."                                          #
#             > MY_KEYRING_PASSWORD="..."                                      #
#                                                                              #
#             EDIT THIS CRIPT TO THEN ADD YOUR DB VALUES TO                    # 
#             FOLLOWING KEYRING SERVICES:                                      #
#             DB.NAME                                                          #
#             DRIVER                                                           #
#             SERVER                                                           #
#             PORT                                                             #
#             HOST                                                             # 
#             USER.NAME                                                        #
#             PASS.WORD                                                        #
#                                                                              #
# ============================================================================ #

## install.packages("keyring")
library(keyring)

## load keyring name
keyring_name = Sys.getenv("MY_KEYRING_NAME")

## load keyring password
keyring_password = Sys.getenv("MY_KEYRING_PASSWORD")
keyring::keyring_unlock(key_ring = keyring_name, password = keyring_password)

## create or unlock existing keyring
if( !(keyring_name %in% keyring::keyring_list()$keyring) ){
  ## create new keyring
  keyring::keyring_create(keyring_name, password = keyring_password)
} else {
  ## unlock existing keyring
  keyring::keyring_unlock(keyring = keyring_name, password = keyring_password)
}


## Needs to be done only once on a machine. Credentials will then be stored in
## the operating system's secure credential manager:
keyring::key_set_with_value(service = "db.name",   keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "driver",    keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "server",    keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "port",      keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "host",      keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "user.name", keyring = keyring_name, password = "...")
keyring::key_set_with_value(service = "pass.word", keyring = keyring_name, password = "...")


## lock keyring after use
keyring::keyring_lock(keyring = keyring_name)

print(keyring::key_list(keyring = keyring_name))

## Delete a keyring
## keyring_delete(keyring = keyring_name)
