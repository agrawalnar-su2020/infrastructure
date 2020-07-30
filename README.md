# AWS Networking Setup

## Infrastructure as Code with Terraform

### Install Terraform
- Download terrafrom from offical website HashiCrop
- Unzip it in root folder

### Install AWS command line interface 
- Install AWS cli
- Configuring AWS cli by setting up profile 

### Build Instructions
- Run commands 
```
 $ terraform initi
 $ terraform plan
 $ terraform apply
```

### Destroy Instruction 
- Run command
```
 $ terraform destroy
```

### Import Ceritificate Using AWS CLI
Use following command to import a certificate using the AWS Command Line Interface (AWS CLI)

```bash
$ openssl x509 -in <youCrtFile>.crt -out <youCertName>.pem
$ openssl x509 -in <yourCaBundleFile>.ca-bundle -out <yourCertChainName>.pem
$ sudo aws acm import-certificate --certificate file://<youCertName>.pem --certificate-chain file://<yourCertChainName>.pem --private-key file:/<yourPrivateKey>.key
```