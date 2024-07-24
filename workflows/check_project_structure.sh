#! /bin/bash

# Written by Tian Fang and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

check_project() {
    EXTENSIONS_TO_CHECK=("m" "c" "cpp" "sh" "csh" "pl" "r")

    EXCLUDED_DIRECTORIES=()
    NO_LONGER_SUPPORT_DIR=()
    STANDALONE_EX_DIR=()
    REPLICATION_EX_DIR=()
    EXAMPLE_EX_DIR=()

    # Flag to indicate whether to check the excluded directories
    no_exclude=false

    # Parse the optional flag --no-exclude
    while [[ "$#" -gt 0 ]]; do
        case $1 in
        --no-exclude)
            no_exclude=true
            shift
            ;;
        *) break ;; # Break the loop if no known flags are found
        esac
    done

    project_path=$1

    if [ "$no_exclude" = false ]; then
        EXCLUDED_DIRECTORIES=($(cat $CBIG_CODE_DIR/hooks/list/exclude_list))
        NO_LONGER_SUPPORT_DIR=($(cat $CBIG_CODE_DIR/hooks/list/no_longer_support_list))
        STANDALONE_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_standalone_list))
        REPLICATION_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_replication_list))
        EXAMPLE_EX_DIR=($(cat $CBIG_CODE_DIR/hooks/list/exclude_example_list))
    fi

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
        echo "[FAILED] Please make sure all scripts have filename CBIG_${project_name}_xxx"
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
        # check whether the project has at least one MATLAB or Python unit test
        ###
        echo -e "\n=====> Check whether the project has at least one MATLAB or Python unit test"
        matlab_test_files=$(find "$project_path/unit_tests" -name "*unit_test.m")
        has_matlab_test=$([ -z "$matlab_test_files" ] && echo 0 || echo 1)
        python_test_files=$(find "$project_path/unit_tests" -name "test_*.py")
        has_python_test=$([ -z "$python_test_files" ] && echo 0 || echo 1)

        if [ $has_matlab_test == 0 ] && [ $has_python_test == 0 ]; then
            exit_flag=1
            echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a MATLAB or Python unit test"
            echo "Please add at least one MATLAB or Python unit test under ./$(realpath --relative-to=. $project_path)/unit_tests manually"
        else
            echo "    [PASSED]"
        fi

        ###
        # check whether all projects with MATLAB unit test have a CBIG_XXX_check_example_results.m script
        ###
        if [ $has_matlab_test == 1 ]; then
            echo -e "\n=====> Check whether this project has a check example script"
            check_script=$(find "$project_path/examples" -name "*check_example_results.m")
            if [[ $check_script == "" ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a check example script"
                echo "Please add CBIG_XXX_check_example_results.m under ./$(realpath --relative-to=. $project_path)/examples manually"
            else
                echo "    [PASSED]"
            fi
        fi

        ###
        # check the content of the MATLAB unit test file if it exists
        ###
        if [ $has_matlab_test == 1 ]; then
            echo -e "\n=====> Check whether the MATLAB unit test wrapper calls the check example function"
            exist_call_check=0
            for unit_test_m in "${matlab_test_files[@]}"; do
                find_check=$(grep check_example_results $unit_test_m)
                if [[ $find_check != "" ]]; then
                    exist_call_check=1
                    break
                fi
            done
            if [ $exist_call_check == 0 ]; then
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not call CBIG_XXX_check_example_results in the MATLAB unit tests."
                echo "Please call CBIG_XXX_check_example_results in your MATLAB unit tests."
                exit_flag=1
            else
                echo "    [PASSED]"
            fi
        fi

        ###
        # check the content of the python unit test file if it exists
        ###
        if [ $has_python_test == 1 ]; then
            echo -e "\n=====> Check whether python unit tests files have at least one function with the prefix 'test_'"
            python_test_file_check=0
            for python_test_file in "${python_test_files[@]}"; do
                find_test_def=$(grep "def test_" $python_test_file)
                if [[ $find_test_def != "" ]]; then
                    python_test_file_check=1
                    break
                fi
            done

            if [ $python_test_file_check == 0 ]; then
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a function with the prefix 'test_' in the python unit tests"
                echo "Please ensure your python unit tests files have at least one function with the prefix 'test_'"
                exit_flag=1
            else
                echo "    [PASSED]"
            fi
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
        # if there are python files in a project, check whether it has CBIG_<project_name>_python_env.yml at either the root of the project or in the replication/config folder
        ###
        py_files=$(find $project_path -name "*.py")
        if [[ ${py_files} ]]; then
            echo -e "\n=====> Check whether this project has CBIG_<project_name>_python_env.yml"
            count=$(find "$project_path" "$project_path/replication/config" -maxdepth 1 -type f -name "*.yml" 2>/dev/null | wc -l)
            if [[ $count == 0 ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have a CBIG_\${project_name}_python_env.yml file"
                echo "Please add CBIG_${project_name}_python_env.yml to ./$(realpath --relative-to=. $project_path) or ./$(realpath --relative-to=. $project_path)/replication/config manually"
            else
                echo "    [PASSED]"
            fi
            # check keras.json
            yml_file=$(ls -1 $project_path/*.yml $project_path/replication/config/*.yml 2>/dev/null)
            keras_line=$(grep keras $yml_file)
            if [[ ! -z "$keras_line" ]]; then
                echo -e "\n=====> Check whether this project has config/keras.json"
                if [[ ! -e $project_path/keras.json && ! -e $project_path/replication/config/keras.json ]]; then
                    exit_flag=1
                    echo "    [FAILED] ./$(realpath --relative-to=. $project_path) does not have keras.json file"
                    echo "Please add keras.json to ./$(realpath --relative-to=. $project_path) or ./$(realpath --relative-to=. $project_path)/replication/config manually"
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
            count=$(find "$project_path/config" -maxdepth 1 -type f -name "*.yml" 2>/dev/null | wc -l)
            if [[ $count == 0 ]]; then
                exit_flag=1
                echo "    [FAILED] ./$(realpath --relative-to=. $project_path)/config/ does not have a CBIG_\${project_name}_python_env.yml file"
                echo "Please add CBIG_${project_name}_python_env.yml to ./$(realpath --relative-to=. $project_path)/config/ manually"
            else
                echo "    [PASSED]"
            fi
            # check keras.json
            yml_file=$(ls -1 $project_path/config/*.yml 2>/dev/null)
            keras_line=$(grep keras $yml_file)
            if [[ ! -z "$keras_line" ]]; then
                echo -e "\n====> Check whether this project has config/keras.json"
                if [[ ! -e $project_path/config/keras.json ]]; then
                    exit_flag=1
                    echo "    [FAILED] ./$(realpath --relative-to=. $project_path)/config/ does not have keras.json file"
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
}
