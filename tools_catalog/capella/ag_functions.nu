  def Alert_Integration [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Alert_Integration" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Allowed_CIDRs__App_Services_ [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Allowed_CIDRs__App_Services_" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Allowed_CIDRs__Cluster_ [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Allowed_CIDRs__Cluster_" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Api_Keys [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Api_Keys" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def App_Endpoints [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "App_Endpoints" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def App_Services [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "App_Services" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def App_Services_Audit_Logging [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "App_Services_Audit_Logging" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Audit_Logs [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Audit_Logs" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Backup_Schedule__Bucket_ [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Backup_Schedule__Bucket_" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Backups___Restore__Bucket_ [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Backups___Restore__Bucket_" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Buckets__Scopes____Collections [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Buckets__Scopes____Collections" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def CMEK [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "CMEK" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Certificates [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Certificates" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Cloud_Snapshot_Backups___Restore [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Cloud_Snapshot_Backups___Restore" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Cloud_Snapshot_Backups_Schedule [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Cloud_Snapshot_Backups_Schedule" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Clusters [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Clusters" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Database_Credentials [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Database_Credentials" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Events [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Events" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Free_Tier [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Free_Tier" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Network_Peers [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Network_Peers" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def On_Off_Schedule [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "On_Off_Schedule" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Organizations [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Organizations" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Private_Endpoint_Service [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Private_Endpoint_Service" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Projects [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Projects" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Query_Indexes [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Query_Indexes" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Sample_Bucket [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Sample_Bucket" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def Users [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "Users" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}