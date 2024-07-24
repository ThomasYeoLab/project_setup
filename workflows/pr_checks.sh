#! /bin/bash

# Written by Tian Fang and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

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
# 4.  Check this project
######
exit_flag=0

echo -e "\n==> [Check 4] Checking this project "

source ${PROJ_DIR}/setup/workflows/check_project_structure.sh
check_project --no-exclude $PROJ_DIR

if [ $exit_flag == 1 ]; then
    echo "[FAILED] Some checks failed."
    exit 1
else
    echo "[PASSED] This project has passed all checks."
fi

exit 0
