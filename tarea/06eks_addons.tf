locals {
  # Copia de la variable de los addons para no modificar la original
  base_addons = var.cluster_addons

  # Actualización del addon agregandole IRSA
  # condición ? valor_si_verdadero : valor_si_falso
  # Si el driver está en la variable de addons, crea un nuevo mapa con la clave del driver
  # y crea un nuevo mapa con el rol iam
  updated_ebs_csi = contains(keys(local.base_addons), "aws-ebs-csi-driver") ? {
    aws-ebs-csi-driver = merge(
      local.base_addons["aws-ebs-csi-driver"],
      {
        service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      }
    )
  } : {}

  # Unión
  final_addons = merge(local.base_addons, local.updated_ebs_csi) #,local.otro_update)

}