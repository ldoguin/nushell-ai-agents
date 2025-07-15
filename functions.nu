  def test [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "test" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def cbes_oai [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "cbes_oai" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def capella_oai [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "capella_oai" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def qwen_general_local [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "qwen_general_local" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def general_oai [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "general_oai" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def qwen_reasoner_local [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "qwen_reasoner_local" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def reviewer [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "reviewer" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
  def writer [query] {
    let result_tool = ( cbsh -c ( $" source agent.nu;  agent_run "writer" "($query)" "  )  ) | complete 
    if ( $result_tool.exit_code == 0 ) { 
      return $result_tool.stdout 
    } else {
      print $result_tool.stderr 
     return $result_tool 
  } 
}
