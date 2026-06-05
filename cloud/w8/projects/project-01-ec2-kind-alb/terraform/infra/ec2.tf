resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = abspath("${path.module}/../../generated/${var.project_name}.pem")
  file_permission = "0600"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "aws_instance" "kind" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = values(aws_subnet.public)[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.this.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm.name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    cluster_name    = var.cluster_name
    kind_version    = var.kind_version
    kubectl_version = var.kubectl_version
    kind_node_image = var.kind_node_image
    node_port       = var.node_port
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-kind-host"
  }
}

resource "terraform_data" "wait_for_kind" {
  depends_on = [aws_instance.kind]

  triggers_replace = [aws_instance.kind.id]

  input = {
    instance_id = aws_instance.kind.id
    public_ip   = aws_instance.kind.public_ip
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = aws_instance.kind.public_ip
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "for i in $(seq 1 120); do if sudo test -f /var/lib/demo-kind-ready; then sudo cat /var/lib/demo-kind-ready; exit 0; fi; sudo tail -n 20 /var/log/demo-kind-bootstrap.log || true; sleep 10; done; exit 1"
    ]
  }
}
