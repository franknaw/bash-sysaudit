# Rough Initial Proof of concept

function getKey() {

echo "Generate Keystore"
rm server-keystore-src.p12 server-keystore.p12

openssl pkcs12 -export -in cert-local.cer -inkey private-key.key -CAfile ca-all.cer -caname root -name my-host-name -out server-keystore-src.p12 -password pass:some-pass
keytool -importkeystore -deststorepass some-pass -destkeypass some-pass -destkeystore server-keystore.p12 -deststoretype pkcs12 -srckeystore server-keystore-src.p12  -srcstoretype pks12 -srcstorepass some-pass -alias the-host-alias

keytool -importcert -file cert-local.cer -alias the-host-alias -keystore server-keystore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-sw.cer -alias the-host-alias -keystore server-keystore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-inter.cer -alias the-host-alias -keystore server-keystore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-root.cer -alias the-host-alias -keystore server-keystore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt

}

function genTrust() {

echo "Generate TrustStore"
rm server-truststore.p12

keytool -importcert -file cert-local.cer -alias the-host-alias -keystore server-truststore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-sw.cer -alias the-host-alias -keystore server-truststore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-inter.cer -alias the-host-alias -keystore server-truststore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt
keytool -importcert -file cert-root.cer -alias the-host-alias -keystore server-truststore.p12 -storetype pkcs12 -deststoretype pkcs12 -storepass the-pass -trustcacerts -noprompt

}

function genCAsChain() {

rm cert-1.cer cert-2.cer cert-3.cer cert-4.cer

openssl pkcs7 -in ca_certificate_chain.p7b -print_certs > all-CAs.txt
awk '/subject=/{n++}{print > cert-" n ".cer"}' all-CAs.txt

}

function renameCAs() {

rm cert-local.cer cert-sw.cer cert-inter.cer cert-root.cer

mv cert-1.cer cert-local.cer
mv cert-2.cer cert-sw.cer
mv cert-3.cer cert-inter.cer
mv cert-4.cer cert-root.cer

}

genCAsChain
renameCAs
genKey
genTrust

