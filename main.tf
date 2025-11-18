/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law of or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {}

locals {
  computed_filter  = join(" OR ", [for app in var.applications : format("logName:projects/%s/logs/%s", var.project_id, app)])
  export_filter    = var.export_filter != "" ? var.export_filter : local.computed_filter
  instance_project = var.instance_project != "" ? var.instance_project : var.project_id
}

#------#
# Data #
#------#

data "template_file" "gsuite_exporter" {
  template = file("${path.module}/scripts/gsuite_exporter.sh.tpl")

  vars = {
    admin_user              = var.admin_user
    api                     = var.api
    applications            = join(" ", var.applications)
    project_id              = var.project_id
    frequency               = var.frequency
    gsuite_exporter_version = var.gsuite_exporter_version
  }
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

#--------------------#
# GSuite Exporter VM #
#--------------------#
resource "google_compute_instance" "gsuite_exporter_vm" {
  name                      = var.instance_name
  machine_type              = var.instance_type
  zone                      = var.zone == null ? data.google_compute_zones.available.names[0] : var.zone
  project                   = local.instance_project
  allow_stopping_for_update = true
  labels                    = var.labels

  boot_disk {
    initialize_params {
      image = var.instance_image
    }
  }

  network_interface {
    network = var.instance_network
    access_config {}
  }

  metadata_startup_script = data.template_file.gsuite_exporter.rendered

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}
