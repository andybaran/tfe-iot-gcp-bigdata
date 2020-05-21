variable "gcloud-project" {
  description = "Google project name"
}

variable "account_file_path" {
  description = "Path to GCP account file"
}

variable "bq_dataset" {
    description = "BigQuery Dataset"
}

variable "bq_table" {
    description = "BigQuery Table"
}

variable "pub_sub_sub" {
  description = "Pub/Sub Subscription to pull from"
}

variable "zone" {
  description = "GCP zone, needed by dataflow"
}

variable "pub_sub_sub" {
    description = "Pub/Sub Subscription"
}