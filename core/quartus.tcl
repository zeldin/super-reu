load_package flow

set argv $quartus(args)

set project_path [lindex $argv 0]
set project_name [lindex $argv 1]
set top_level_entity [lindex $argv 2]
set filenames [lrange $argv 3 end]

set project_up [file join {*}[lmap v [file split $project_path] {
 if {$v=="."} continue
 if {$v==".." || $v=="/"} {error "Invalid project path"}
 lindex ..
}]]

file mkdir $project_path
cd $project_path
project_new $project_name -revision $project_name -overwrite

set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name TOP_LEVEL_ENTITY $top_level_entity

foreach filename $filenames {
  set filename [file join $project_up $filename]
  set suffix [string range $filename [string last . $filename] end]
  if {$suffix==".tcl"} {
    source $filename
  } elseif {$suffix==".sdc"} {
    set_global_assignment -name SDC_FILE $filename
  } elseif {$suffix==".vhd"} {
    set_global_assignment -name VHDL_FILE $filename
  } elseif {$suffix==".v"} {
    set_global_assignment -name VERILOG_FILE $filename
  } else {
    error "Unknown suffix $suffix"
  }
}

cd $project_up

# Synthesize and compile project
execute_flow -compile

project_close
