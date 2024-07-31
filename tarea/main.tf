#Data
data "aws_availability_zones" "available" {}
#Devuelve una lista de todas las zonas de disponibilidad disponibles en la región actual
data "aws_region" "current" {}
# obtiene la información de la región configurada actualmente.
