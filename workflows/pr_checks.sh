######
# 1. (different files between origin/main and current branch)[.m, .sh, .csh]
######
###
# Find the files that we want to check
###
files_to_be_checked=$CHANGED_FILES

EXTENSIONS_TO_CHECK=("m" "sh" "csh")
EXCLUDED_FILES=("Surf2SurfGui.m" "Vol2SurfGui.m" "CBIG_tested_config.sh" "CBIG_tested_config.csh")

###
# Check whether function CBIG_xxx has been used in other functions
###
echo -e "\n==> [Check 1] Checking whether function CBIG_xxx has been used in other functions"
for file_path in "${files_to_be_checked[@]}"; do
    file_name=($(basename "$file_path"))

    # check whether file should be excluded
    file_in_excluded=0
    for excluded_file in "${EXCLUDED_FILES[@]}"; do
        if [[ $file_name == $excluded_file ]]; then
            file_in_excluded=1
            break
        fi
    done
    if [[ $file_in_excluded == 1 ]]; then
        continue
    fi

    for ext in "${EXTENSIONS_TO_CHECK[@]}"; do
        if [[ $file_name == *.$ext ]]; then
            echo -e "\n  ==> Checking ./$(realpath --relative-to=. $file_path)"
            $CBIG_CODE_DIR/setup/check_function_format/CBIG_check_whether_function_used_in_other_functions_wrapper.sh \
                $file_path silent
        fi
    done
done
echo "  [DONE]"
###
# comments about replacing function name
###
echo -e "\n==> [Useful function] Replace old function name with new function name"
echo "If you have renamed a function and want to change all instances of old function to the new function, you can use: "
echo "setup/replace_old_with_new_func_name/CBIG_replace_old_with_new_function_name_wrapper.sh"
echo ""

######
# 2.  (different files between origin/develop and current branch)[.m, .sh, .csh]
######
unset files_to_be_checked
files_to_be_checked=$CHANGED_FILES

EXTENSIONS_TO_CHECK=("m" "sh" "csh")
EXCLUDED_FILES=("Surf2SurfGui.m" "Vol2SurfGui.m" "CBIG_tested_config.sh" "CBIG_tested_config.csh")

TARGET_DIRECTORIES=("utilities" "stable_projects" "data" "external_packages")

###
# Check whether function name xxx has conflict with other function names
###
echo -e "\n==> [Check 2] Checking whether function name xxx has conflict with other function names"
for file_path in "${files_to_be_checked[@]}"; do
    file_name=($(basename "$file_path"))
    filename_with_conflict=0
    file_in_nondefault=0

    # check whether file should be excluded
    file_in_excluded=0
    for excluded_file in "${EXCLUDED_FILES[@]}"; do
        if [[ $file_name == $excluded_file ]]; then
            file_in_excluded=1
            break
        fi
    done
    if [[ $file_in_excluded == 1 ]]; then
        continue
    fi

    for ext in "${EXTENSIONS_TO_CHECK[@]}"; do
        if [[ $file_name == *.$ext && $file_path != *@* && $file_path != *matlab_bgl_mac64* ]]; then
            echo -e "\n  ==> Checking ./$(realpath --relative-to=. $file_path)"
            # find all matches of filename
            all_matches=""
            i=0
            for target_dir in "${TARGET_DIRECTORIES[@]}"; do
                i=$((i + 1))
                matches=$(find $CBIG_CODE_DIR/$target_dir -type f -name "$file_name" ! \
                    -samefile $CBIG_CODE_DIR/$file_path ! -path "*/@*/*" ! -path "*/matlab_bgl_mac64/*")
                if [[ $matches ]]; then
                    if [ $i == 1 ]; then
                        all_matches="$matches"
                    else
                        all_matches="$all_matches $matches"
                    fi
                fi
            done

            if [[ ${all_matches} ]]; then
                # check all matches
                for match in "${all_matches[@]}"; do
                    if [[ $match != */non_default_packages/* ]] && [[ $file_path != */non_default_packages/* ]]; then
                        filename_with_conflict=1
                    fi
                    if [[ $match == */non_default_packages/* ]] || [[ $file_path == */non_default_packages/* ]]; then
                        file_in_nondefault=1
                    fi
                    echo "$match"
                done
                if [[ $filename_with_conflict == 1 ]]; then
                    echo "[FAILED] Abort pushing."
                fi
                if [[ $file_in_nondefault == 1 ]]; then
                    echo "[WARNING] The user should discuss with the admin about how to handle the conflicts."
                fi
            fi
        fi
    done
done
if [ $filename_with_conflict == 0 -a $file_in_nondefault == 0 ]; then
    echo "  [PASSED]"
fi

######
# 3.  (folders of different files between origin/main and current branch)[@xxx]
######
unset files_to_be_checked
files_to_be_checked=$CHANGED_FILES

TARGET_DIRECTORIES=("utilities" "stable_projects" "data" "external_packages")

# find the folders of committed files
cnt=${#files_to_be_checked[@]}
for ((i = 0; i < cnt; i++)); do
    folders_to_be_checked[i]=$(dirname ${files_to_be_checked[i]})
done
unique_folders_to_be_checked=($(echo ${folders_to_be_checked[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

###
# Check whether class name @xxx has conflict with other class names
###
echo -e "\n==> [Check 3] Checking whether Matlab class name @xxx has conflict with other class names"
for folder_path in "${unique_folders_to_be_checked[@]}"; do
    folder_name=($(basename "$folder_path"))
    classname_with_conflict=0
    class_in_nondefault=0

    if [[ $folder_name == @* ]]; then
        echo -e "\n  ==> Checking ./$(realpath --relative-to=. $folder_path)"
        all_matches=""
        i=0
        for target_dir in "${TARGET_DIRECTORIES[@]}"; do
            matches=$(find $CBIG_CODE_DIR/$target_dir -name "$folder_name" ! -samefile $CBIG_CODE_DIR/$folder_path)
            if [[ ${matches} ]]; then
                if [ $i == 1 ]; then
                    all_matches="$matches"
                else
                    all_matches="$all_matches $matches"
                fi
            fi
        done
        if [[ ${all_matches} ]]; then
            # check all matches
            for match in "${all_matches[@]}"; do
                if [[ $match != */non_default_packages/* ]] && [[ $folder_path != */non_default_packages/* ]]; then
                    classname_with_conflict=1
                fi
                if [[ $match == */non_default_packages/* ]] || [[ $folder_path == */non_default_packages/* ]]; then
                    class_in_nondefault=1
                fi
                echo "!!!Find conflict: $match"
            done
            if [[ $classname_with_conflict == 1 ]]; then
                echo "[FAILED] Abort pushing."
            fi
            if [[ $class_in_nondefault == 1 ]]; then
                echo "[WARNING] The user should discuss with the admin about how to handle the conflicts."
            fi
        fi
    fi
done
if [ $classname_with_conflict == 0 -a $class_in_nondefault == 0 ]; then
    echo "  [PASSED]"
fi

######
# 4.  (files in stable_projects/xxx/xxx (exclude Thomas, Alex, Gia, Xiuming, Raphael))[.m, .c, .cpp, .sh, .csh, .py, .pl, .r]
######
exit_flag=0
EXTENSIONS_TO_CHECK=("m" "c" "cpp" "sh" "csh" "pl" "r")
EXCLUDED_DIRECTORIES=($(cat $CBIG_CODE_DIR/hooks/list/exclude_list))
NO_LONGER_SUPPORT_DIR=($(cat $CBIG_CODE_DIR/hooks/list/no_longer_support_list))
STANDALONE_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_standalone_list))
REPLICATION_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_replication_list))
EXAMPLE_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_example_list))

# Parse .gitsubmodule file to get submodule paths
submodule_paths=$(awk '/path = stable_projects/ { print $3 }' $CBIG_CODE_DIR/.gitmodules)
# Convert submodule_paths to array
readarray -t submodule_array <<<"$submodule_paths"
# Create a pattern for grep to exclude submodule paths
exclude_pattern=$(
    IFS='|'
    echo "${submodule_array[*]}"
)
# Get project paths excluding submodule paths
project_paths=$(ls -d -1 $CBIG_CODE_DIR/stable_projects/*/* | grep -vE "$exclude_pattern")

echo -e "\n==> [Check 4] Checking stable_projects/xxx/xxx "
for project_path in $project_paths; do
    project_in_exclude_directory=0
    project_folder_name=($(basename "$project_path"))
    echo -e "\n===> Checking ./$(realpath --relative-to=. $project_path)"
    all_with_valid_prefix=1
    for exclude_directory in "${EXCLUDED_DIRECTORIES[@]}"; do
        if [[ "$project_path" == */${exclude_directory} ]]; then
            echo "    [SKIPPED] $project_folder_name is excluded from all checks."
            project_in_exclude_directory=1
            break
        fi
    done
    if [[ $project_in_exclude_directory == 1 ]]; then
        continue
    fi
    project_retired=0
    # check no longer supported directories
    for retired_dir in "${NO_LONGER_SUPPORT_DIR[@]}"; do
        if [[ "$project_path" == */${retired_dir} ]]; then
            echo " $project_folder_name is no longer supported. This folder should only contain one readme file"
            project_retired=1
            break
        fi
    done
    if [[ $project_retired == 1 ]]; then
        if [ ! -f "${project_path}/README.md" ]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a readme file"
        fi
        if [ $(ls ${project_path} | wc -l) -gt 1 ]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) should only have one readme file"
        fi
        continue
    fi

    cmd="files_in_project=(\$(find $project_path -type f"
    i=0
    for ext in ${EXTENSIONS_TO_CHECK[@]}; do
        i=$((i + 1))
        if [ $i == 1 ]; then
            cmd="$cmd -name \"*.$ext\""
        else
            cmd="$cmd -or -name \"*.$ext\""
        fi
    done
    cmd="$cmd))"
    eval $cmd
    ###
    # find the project name based on first file
    ###
    first_file="${files_in_project[0]}"
    first_filename=($(basename "$first_file"))
    project_name=$(echo $first_filename | awk -F '_' '{print $2}')

    ###
    # check whether function name follows CBIG_<project_name>_xxx
    ###
    echo -e "\n====> Check whether all function names follow CBIG_<project_name>_xxx"
    i=0
    for file_path in "${files_in_project[@]}"; do
        i=$((i + 1))
        if [[ "$i" != "1" ]]; then
            filename=($(basename "$file_path"))
            if [[ "$filename" != "CBIG_${project_name}_"* ]]; then
                echo "!!!Find problematic file: ./$(realpath --relative-to=. $file_path)"
                all_with_valid_prefix=0
            fi
        fi

    done
    if [[ $all_with_valid_prefix == 0 ]]; then
        exit_flag=1
        echo "[FAILED] Please make sure all scripts have filename CBIG_<project_name>_xxx"
    else
        echo "    [PASSED]"
    fi

    ###
    # check whether all projects have the unit_tests folder
    ###
    echo -e "\n====> Check whether this project has unit_tests folder"
    if [ ! -d "$project_path/unit_tests" ]; then
        exit_flag=1
        echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a unit_tests folder"
        echo "Please add a unit_tests folder under ./$(realpath --relative-to=. $project_path) manually"
    else
        echo "    [PASSED]"
    fi

    ###
    # check whether all projects have the examples folder
    ###
    project_in_example_ex_dir=0
    echo -e "\n====> Check whether this project has examples folder"
    for exclude_directory in "${EXAMPLE_EX_DIR[@]}"; do
        if [[ "$project_path" == */${exclude_directory} ]]; then
            project_in_example_ex_dir=1
            echo "    [SKIPPED] $project_folder_name is excluded from example folder check."
            break
        fi
    done

    if [[ $project_in_example_ex_dir == 0 ]]; then
        if [ ! -d "$project_path/examples" ]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a examples folder"
            echo "Please add a examples folder under ./$(realpath --relative-to=. $project_path) manually"
        else
            echo "    [PASSED]"
        fi

        ###
        # check whether all projects have a CBIG_XXX_check_example_results.m script
        ###
        echo -e "\n=====> Check whether this project has a check example script"
        check_script=$(find "$project_path/examples" -name "*check_example_results.m")
        if [[ $check_script == "" ]]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a check example script"
            echo "Please add CBIG_XXX_check_example_results.m under ./$(realpath --relative-to=. $project_path)/examples manually"
        else
            echo "    [PASSED]"
        fi

        ###
        # check whether the unit test wrapper calls the check example function
        ###
        echo -e "\n=====> Check whether the unit test wrapper calls the check example function"
        unit_test_files=$(find "$project_path/unit_tests" -name "*unit_test.m")
        exist_call_check=0
        for unit_test_m in "${unit_test_files[@]}"; do
            find_check=$(grep check_example_results $unit_test_m)
            if [[ $find_check != "" ]]; then
                exist_call_check=1
                break
            fi
        done
        if [ $exist_call_check == 0 ]; then
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not call CBIG_XXX_check_example_results in the unit tests."
            echo "Please call CBIG_XXX_check_example_results in your unit tests."
            exit_flag=1
        else
            echo "    [PASSED]"
        fi
    fi

    ###
    # check whether all projects have the replication folder
    ###
    project_in_replication_ex_dir=0
    echo -e "\n====> Checking replication folder .."
    for exclude_directory in "${REPLICATION_EX_DIR[@]}"; do
        if [[ "$project_path" == */${exclude_directory} ]]; then
            project_in_replication_ex_dir=1
            echo "    [SKIPPED] $project_folder_name is excluded from replication folder check."
            break
        fi
    done
    if [[ $project_in_replication_ex_dir == 0 ]]; then
        echo -e "\n=====> Check whether this project has replication folder"
        if [ ! -d "$project_path/replication" ]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a replication folder"
            echo "Please add a replication folder under ./$(realpath --relative-to=. $project_path) manually"
        else
            echo "    [PASSED]"
        fi

        ###
        # check whether all projects have a standardized config file under replication/config
        ###
        echo -e "\n=====> Check whether this project has a standardized CBIG_<project_name>_tested_config.sh"
        all_with_config=1
        config_path_sh="$project_path/replication/config/CBIG_${project_name}_tested_config.sh"
        config_path_csh="$project_path/replication/config/CBIG_${project_name}_tested_config.csh"
        if [[ -e $config_path_sh ]]; then
            secondline=$(sed -n 2p $config_path_sh)
            if [[ "$secondline" != "# Last successfully run on"* ]]; then
                all_with_config=0
                echo "./$(realpath --relative-to=. $project_path)/replication/config/CBIG_${project_name}_tested_config.sh does not have the time stamp"
            fi
            if [[ "$secondline" != *"git repository version"* ]]; then
                all_with_config=0
                echo "./$(realpath --relative-to=. $project_path)/replication/config/CBIG_${project_name}_tested_config.sh does not have the git version"
            fi
            env_test=$(grep CBIG_TESTDATA_DIR $config_path_sh)
            if [[ "$env_test" == "" ]]; then
                echo "./$(realpath --relative-to=. $config_path_sh) does not define CBIG_TESTDATA_DIR"
                all_with_config=0
            fi
            rep_test=$(grep CBIG_REPDATA_DIR $config_path_sh)
            if [[ "$rep_test" == "" ]]; then
                rep_test=$(grep CBIG_${project_name}_REP_.*_DIR $config_path_sh)
                if [[ "$rep_test" == "" ]]; then
                    echo "./$(realpath --relative-to=. $config_path_sh) does not define CBIG_REPDATA_DIR"
                    all_with_config=0
                fi
            fi
        elif [[ -e $config_path_csh ]]; then
            secondline=$(sed -n 2p $config_path_csh)
            if [[ "$secondline" != "# Last successfully run on"* ]]; then
                all_with_config=0
                echo "./$(realpath --relative-to=. $project_path)/replication/config/CBIG_${project_name}_tested_config.csh does not have the time stamp"
                echo "The second line of the config file should be a comment:"
                echo "# Last successfully run on <spelled out date to reduce confusion, e.g., Jan 7th, 2017> with git \
repository version <vx.x.x-version_name>"
            fi
            env_test=$(grep CBIG_TESTDATA_DIR $config_path_csh)
            if [[ "$env_test" == "" ]]; then
                echo "./$(realpath --relative-to=. $config_path_csh) does not define CBIG_TESTDATA_DIR"
                all_with_config=0
            fi
            rep_test=$(grep CBIG_REPDATA_DIR $config_path_csh)
            if [[ "$rep_test" == "" ]]; then
                rep_test=$(grep CBIG_${project_name}_REP_.*_DIR $config_path_csh)
                if [[ "$rep_test" == "" ]]; then
                    echo "./$(realpath --relative-to=. $config_path_csh) does not define CBIG_REPDATA_DIR"
                    all_with_config=0
                fi
            fi
        else
            echo "./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_tested_config file"
            echo "Please add CBIG_${project_name}_tested_config.sh or CBIG_${project_name}_tested_config.csh to \
$project_path/config/ manually"
            echo "Each stable project should contain a repo config file that was used when the project was last \
tested to work."
            echo "The second line of the config file should be a comment:"
            echo "# Last successfully run on <spelled out date to reduce confusion, e.g., Jan 7th, 2017> with git \
repository version <vx.x.x-version_name>"
            all_with_config=0
        fi
        if [ $all_with_config == 0 ]; then
            exit_flag=1
            echo "    [FAILED] Stable_project ./$(realpath --relative-to=. $project_path) does not have CBIG_${project_name}_tested_config files \
or these files do not meet the above requirements."
        else
            echo "    [PASSED]"
        fi

        ###
        # if there are matlab files in a project, check whether it has config/CBIG_<project_name>_tested_startup.m
        ###
        m_files=$(find $project_path -name "*.m")
        if [[ ${m_files} ]]; then
            echo -e "\n=====> Check whether this project has CBIG_<project_name>_tested_startup.m"
            if [[ ! -e $project_path/replication/config/CBIG_${project_name}_tested_startup.m ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_tested_startup.m file"
                echo "Please add CBIG_${project_name}_tested_startup.m to ./$(realpath --relative-to=. $project_path)/replication/config/ manually"
            else
                echo "    [PASSED]"
            fi
        fi

        ###
        # if there are python files in a project, check whether it has config/CBIG_<project_name>_python_env.txt
        ###
        py_files=$(find $project_path -name "*.py")
        if [[ ${py_files} ]]; then
            echo -e "\n=====> Check whether this project has CBIG_<project_name>_python_env.yml"
            count=$(ls -1 $project_path/replication/config/*.yml 2>/dev/null | wc -l)
            if [[ $count == 0 ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_\${project_name}_python_env.yml file"
                echo "Please add CBIG_${project_name}_python_env.yml to ./$(realpath --relative-to=. $project_path)/replication/config/ manually"
            else
                echo "    [PASSED]"
            fi
            # check keras.json
            yml_file=$(ls -1 $project_path/replication/config/*.yml)
            keras_line=$(grep keras $yml_file)
            if [[ ! -z "$keras_line" ]]; then
                echo -e "\n=====> Check whether this project has config/keras.json"
                if [[ ! -e $project_path/replication/config/keras.json ]]; then
                    exit_flag=1
                    echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have keras.json file"
                    echo "Please add keras.json to ./$(realpath --relative-to=. $project_path)/replication/config/ manually"
                else
                    echo "    [PASSED]"
                fi
            fi
        fi

        ###
        # check whether the project has replication/config/CBIG_<project_name>_generate_standalone.sh
        ###
        project_in_standalone_ex_dir=0
        for exclude_directory in "${STANDALONE_EX_DIR[@]}"; do
            if [[ "$project_path" == */${exclude_directory} ]]; then
                project_in_standalone_ex_dir=1
                break
            fi
        done
        if [[ $project_in_standalone_ex_dir == 0 ]]; then
            echo -e "\n=====> Check whether this project has CBIG_<project_name>_generate_standalone.sh"
            if [[ ! -e $project_path/replication/config/CBIG_${project_name}_generate_standalone.sh ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_generate_standalone.sh"
                echo "Please add CBIG_${project_name}_generate_standalone.sh to ./$(realpath --relative-to=. $project_path)/config/ manually"
            else
                echo "    [PASSED]"
            fi
        fi
    else
        ###
        # check whether all projects have a standardized config file
        ###
        echo -e "\n====> Check whether this project has a standardized config/CBIG_<project_name>_tested_config.sh"
        all_with_config=1
        config_path_sh="$project_path/config/CBIG_${project_name}_tested_config.sh"
        config_path_csh="$project_path/config/CBIG_${project_name}_tested_config.csh"
        if [[ -e $config_path_sh ]]; then
            secondline=$(sed -n 2p $config_path_sh)
            if [[ "$secondline" != "# Last successfully run on"* ]]; then
                all_with_config=0
                echo "./$(realpath --relative-to=. $project_path)/config/CBIG_${project_name}_tested_config.sh does not have the time stamp"
                echo "The second line of the config file should be a comment:"
                echo "# Last successfully run on <spelled out date to reduce confusion, e.g., Jan 7th, 2017>"
            fi
            env_test=$(grep CBIG_TESTDATA_DIR $config_path_sh)
            if [[ "$env_test" == "" ]]; then
                echo "./$(realpath --relative-to=. $config_path_sh) does not define CBIG_TESTDATA_DIR"
                all_with_config=0
            fi
        elif [[ -e $config_path_csh ]]; then
            secondline=$(sed -n 2p $config_path_csh)
            if [[ "$secondline" != "# Last successfully run on"* ]]; then
                all_with_config=0
                echo "./$(realpath --relative-to=. $project_path)/config/CBIG_${project_name}_tested_config.csh does not have the time stamp"
            fi
            env_test=$(grep CBIG_TESTDATA_DIR $config_path_csh)
            if [[ "$env_test" == "" ]]; then
                echo "./$(realpath --relative-to=. $config_path_csh) does not define CBIG_TESTDATA_DIR"
                all_with_config=0
            fi
        else
            echo "./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_tested_config file"
            echo "Please add CBIG_${project_name}_tested_config.sh or CBIG_${project_name}_tested_config.csh to \
$project_path/config/ manually"
            echo "The second line of the config file should be a comment:"
            echo "# Last successfully run on <spelled out date to reduce confusion, e.g., Jan 7th, 2017>"
            all_with_config=0
        fi
        if [ $all_with_config == 0 ]; then
            exit_flag=1
            echo "    [FAILED] Stable_project ./$(realpath --relative-to=. $project_path) does not have CBIG_${project_name}_tested_config files \
or these files do not meet the above requirements."
        else
            echo "    [PASSED]"
        fi

        ###
        # if there are matlab files in a project, check whether it has config/CBIG_<project_name>_tested_startup.m
        ###
        m_files=$(find $project_path -name "*.m")
        if [[ ${m_files} ]]; then
            echo -e "\n====> Check whether this project has config/CBIG_<project_name>_tested_startup.m"
            if [[ ! -e $project_path/config/CBIG_${project_name}_tested_startup.m ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_tested_startup.m file"
                echo "Please add CBIG_${project_name}_tested_startup.m to $project_path/config/ manually"
            else
                echo "    [PASSED]"
            fi
        fi

        ###
        # if there are python files in a project, check whether it has config/CBIG_<project_name>_python_env.txt
        ###
        py_files=$(find $project_path -name "*.py")
        if [[ ${py_files} ]]; then
            echo -e "\n====> Check whether this project has config/CBIG_<project_name>_python_env.yml"
            count=$(ls -1 $project_path/config/*.yml 2>/dev/null | wc -l)
            if [[ $count == 0 ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_\${project_name}_python_env.yml file"
                echo "Please add CBIG_${project_name}_python_env.yml to ./$(realpath --relative-to=. $project_path)/config/ manually"
            else
                echo "    [PASSED]"
            fi
            # check keras.json
            yml_file=$(ls -1 $project_path/config/*.yml)
            keras_line=$(grep keras $yml_file)
            if [[ ! -z "$keras_line" ]]; then
                echo -e "\n====> Check whether this project has config/keras.json"
                if [[ ! -e $project_path/config/keras.json ]]; then
                    exit_flag=1
                    echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have keras.json file"
                    echo "Please add keras.json to ./$(realpath --relative-to=. $project_path)/config/ manually"
                else
                    echo "    [PASSED]"
                fi
            fi
        fi

        ###
        # check whether the project has config/CBIG_<project_name>_generate_standalone.sh
        ###
        project_in_standalone_ex_dir=0
        for exclude_directory in "${STANDALONE_EX_DIR[@]}"; do
            if [[ "$project_path" == */${exclude_directory} ]]; then
                project_in_standalone_ex_dir=1
                break
            fi
        done
        if [[ $project_in_standalone_ex_dir == 0 ]]; then
            echo -e "\n====> Check whether this project has config/CBIG_<project_name>_generate_standalone.sh"
            if [[ ! -e $project_path/config/CBIG_${project_name}_generate_standalone.sh ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_${project_name}_generate_standalone.sh"
                echo "Please add CBIG_${project_name}_generate_standalone.sh to $project_path/config/ manually"
            else
                echo "    [PASSED]"
            fi
        fi
    fi
done

if [ $exit_flag == 1 ]; then
    echo "[FAILED] Some checks failed."
    exit 1
else
    echo "[PASSED]"
fi

exit 0
