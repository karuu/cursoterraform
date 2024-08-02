output "public_ip" {
  description = "IP Address of server built with Server Module"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  value = aws_instance.web.public_dns
}

output "size"{
    description = "Hola, soy una descripción del tamaño"
    value = aws_instance.web.instance_type

}
