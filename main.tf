provider "google" {
  credentials = file(var.account_file_path)
  project     = var.gcloud-project
  user_project_override = true
}

resource "google_project_service" "service" {
    for_each = toset([
        "bigquery.googleapis.com",
        "dataflow.googleapis.com",
        "pubsub.googleapis.com",
        "cloudiot.googleapis.com"
    ])
    
    service = each.key
    project =  var.gcloud-project
    disable_dependent_services = true
    disable_on_destroy = false

}

// ************************************************************   
// IoT Core
// ************************************************************  

resource "google_cloudiot_registry" "iot_registry" { 
    depends_on = [google_pubsub_topic.pst_diagnostic_data, google_project_service.service]
    
    name = "obd2_devices"
    project =  var.gcloud-project
    event_notification_configs {
        pubsub_topic_name = "projects/${var.gcloud-project}/topics/diagnostic_data"
    }
    mqtt_config = {
        mqtt_enabled_state = "MQTT_ENABLED"
    }
    http_config = {
        http_enabled_state = "HTTP_ENABLED"
    }
}

// ************************************************************   
// Cloud Pub Sub
// ************************************************************  

resource "google_pubsub_topic" "pst_diagnostic_data" {
    depends_on = [google_project_service.service]
    name = "diagnostic_data"
    project = var.gcloud-project
}

resource "google_pubsub_subscription" "pst_diagnostic_data_sub" {
    depends_on = [google_pubsub_topic.pst_diagnostic_data]
    name = var.pub_sub_sub
    project = var.gcloud-project
    topic = google_pubsub_topic.pst_diagnostic_data.name
    
    message_retention_duration = "86400s"
    retain_acked_messages = true
}

// ************************************************************   
// BigQuery Dataset & Table
// ************************************************************   

resource "google_bigquery_dataset" "obd2info" {
    dataset_id = var.bq_dataset
    friendly_name = var.bq_dataset
    description = "Dataset containing tables related to OBD2 diagnostic logs"
    location = "US"

    depends_on = [google_project_service.service]

   /* access {
        role = "projects/${var.gcloud-project}/roles/bigquery.admin"
        special_group = "projectOwners"
    }

    access {
        role = "projects/${var.gcloud-project}/roles/bigquery.dataEditor"
        special_group = "projectWriters"
    }

    access {
        role = "projects/${var.gcloud-project}/roles/bigquery.dataViewer"
        special_group = "projectReaders"
    }

    access {
        role = "projects/${var.gcloud-project}/roles/bigquery.jobUser"
        special_group = "projectWriters"
    }

    access {
        role = "projects/${var.gcloud-project}/bigquery.jobUser"
        special_group = "projectReaders"
    }*/
}

resource "google_bigquery_table" "obd2logging" {
    dataset_id = google_bigquery_dataset.obd2info.dataset_id
    table_id = var.bq_table

    schema = <<EOF
    [
    {
        "mode": "NULLABLE", 
        "name": "VIN", 
        "type": "STRING"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "collectedAt", 
        "type": "STRING"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_RPM", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_ENGINE_LOAD", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_COOLANT_TEMP", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_ABSOLUTE_ENGINE_LOAD", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_TIMING_ADVANCE", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_ENGINE_OIL_TEMP", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE", 
        "name": "PID_ENGINE_TORQUE_PERCENTAGE", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE",
        "name": "PID_ENGINE_REF_TORQUE", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE",   
        "name": "PID_INTAKE_TEMP", 
        "type": "FLOAT"
      },
      {
        "mode": "NULLABLE",   
        "name": "PID_MAF_FLOW", 
        "type": "FLOAT"
      },
      {
        "mode": "NULLABLE", 
        "name": "PID_BAROMETRIC", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE",  
        "name": "PID_SPEED", 
        "type": "FLOAT"
      }, 
      {
        "mode": "NULLABLE",   
        "name": "PID_RUNTIME", 
        "type": "FLOAT"
      },
      {
        "mode": "NULLABLE",   
        "name": "PID_DISTANCE", 
        "type": "FLOAT"
      }
    ]
    EOF


}


// ************************************************************   
// Dataflow Job (PubSub --> BigQuery Table)
// ************************************************************   

resource "google_storage_bucket" "dataflow_bucket" {
  name = join("",["dataflow-", var.gcloud-project])
  location = "US"
}

resource "google_dataflow_job" "collect_OBD2_data" {
  name              = "OBD2-Data-Collection"
  zone = var.zone
  template_gcs_path = "gs://dataflow-templates/latest/PubSub_Subscription_to_BigQuery"
  temp_gcs_location = "${google_storage_bucket.dataflow_bucket.url}/tmp_dir"
  parameters = {
    inputSubscription = "projects/${var.gcloud-project}/subscriptions/${var.pub_sub_sub}"
    outputTableSpec = "${var.gcloud-project}:${var.bq_table}"
    #flexRSGoal = "COST_OPTIMIZED"
  }
}