module "worker_amitype" {
  source        = "github.com/terraform-community-modules/tf_aws_virttype"
  instance_type = "${var.worker_instance_type}"
}

module "worker_ami" {
  source   = "github.com/terraform-community-modules/tf_aws_coreos_ami"
  region   = "${var.region}"
  channel  = "${var.coreos_channel}"
  virttype = "${module.worker_amitype.prefer_hvm}"
}

resource "template_file" "worker_cloud_init" {
  template   = "worker-cloud-config.yml.tpl"
  depends_on = ["template_file.etcd_discovery_url"]
  vars {
    etcd_discovery_url = "${file(var.etcd_discovery_url_file)}"
    size               = "${var.masters}"
    region             = "${var.region}"
  }
}

resource "aws_instance" "worker" {
  instance_type     = "${var.worker_instance_type}"
  ami               = "${module.worker_ami.ami_id}"
  count             = "${var.workers}"
  key_name          = "${module.aws-keypair.keypair_name}"
  subnet_id         = "${element(split(",", module.public_subnet.subnet_ids), count.index)}"
  source_dest_check = false
  security_groups   = ["${module.sg-default.security_group_id}"]
  depends_on        = ["aws_instance.master"]
  user_data         = "${template_file.worker_cloud_init.rendered}"
  tags = {
    Name = "kube-worker-${count.index}"
    role = "workers"
  }
  ebs_block_device {
    device_name           = "/dev/xvdb"
    volume_size           = "${var.worker_ebs_volume_size}"
    delete_on_termination = true
  }
}
