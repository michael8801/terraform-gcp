terraform {
 backend "gcs" {
   bucket  = "terraform-state-oleshchenko"
   prefix  = "terraform/state"
   credentials = "/home/mickeymouse/credentials-gcp/iac-1/cred-gcp.json"
 }
    
}
