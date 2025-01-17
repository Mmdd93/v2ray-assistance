#!/bin/bash

file_management() {
    clear
    
    echo -e "\033[1;32mFile Management Menu\033[0m"
    

    while true; do
        echo -e "\n\033[1;33mChoose an action:\033[0m"
        echo -e "1. \033[1;32mCopy\033[0m"
        echo -e "2. \033[1;31mRemove\033[0m"
        echo -e "3. \033[1;34mMove\033[0m"
        echo -e "4. \033[1;36mRename\033[0m"
        echo -e "5. \033[1;35mView Date Modified\033[0m"
        echo -e "6. \033[1;37mView File Details\033[0m"
        echo -e "7. \033[1;33mChange File Permissions\033[0m"
        echo -e "8. \033[1;32mCreate Directory\033[0m"
        echo -e "9. \033[1;31mView File Content\033[0m"
        echo -e "10. \033[1;34mSearch for File by Name\033[0m"
        echo -e "11. \033[1;36mCheck Disk Usage\033[0m"
        echo -e "12. \033[1;34mChange Ownership\033[0m"
        echo -e "13. \033[1;33mChange File Group\033[0m"
        echo -e "14. \033[1;35mConvert DOS to Unix\033[0m"
		echo -e "15. \033[1;35mFind big files\033[0m"
        echo -e "0. \033[1;33mReturn to Main Menu\033[0m"

        read -p "Enter your choice: " action

        case $action in
            1)
                # Copy action
                read -p "Enter the source file path: " file_path
                read -p "Enter the destination path: " dest_path
                if [ ! -f "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist or is not a valid file.\033[0m"
                    continue
                fi
                if [ ! -d "$(dirname "$dest_path")" ]; then
                    echo -e "\033[1;31mError: The destination directory does not exist.\033[0m"
                    continue
                fi
                cp "$file_path" "$dest_path"
                echo -e "\033[1;32mFile copied successfully!\033[0m"
                ;;
            2)
                # Remove action
                read -p "Enter the file or directory path to remove: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                rm -rf "$file_path"
                echo -e "\033[1;32m'$file_path' removed successfully!\033[0m"
                ;;
            3)
                # Move action
                read -p "Enter the source file path: " file_path
                read -p "Enter the destination path: " dest_path
                if [ ! -f "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist or is not a valid file.\033[0m"
                    continue
                fi
                if [ ! -d "$(dirname "$dest_path")" ]; then
                    echo -e "\033[1;31mError: The destination directory does not exist.\033[0m"
                    continue
                fi
                mv "$file_path" "$dest_path"
                echo -e "\033[1;32mFile moved successfully!\033[0m"
                ;;
            4)
                # Rename action
                read -p "Enter the current file or directory path: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                read -p "Enter the new name: " new_name
                mv "$file_path" "$(dirname "$file_path")/$new_name"
                echo -e "\033[1;32m'$file_path' renamed to '$new_name' successfully!\033[0m"
                ;;
            5)
                # View Date Modified action
                read -p "Enter the file or directory path: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                date_modified=$(stat -c %y "$file_path")
                echo -e "\033[1;32mDate Modified: $date_modified\033[0m"
                ;;
            6)
                # View File Details action
                read -p "Enter the file or directory path: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                file_details=$(ls -l "$file_path")
                echo -e "\033[1;32mFile Details:\n$file_details\033[0m"
                ;;
            7)
					# Change File Permissions action
					read -p "Enter the file path: " file_path
					if [ ! -e "$file_path" ]; then
						echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
						continue
					fi

					echo -e "\n\033[1;33mSelect the permission you want to apply:\033[0m"
					echo -e "1. \033[1;32m755\033[0m - Owner: read/write/execute, Group: read/execute, Others: read/execute (Common for executable files)"
					echo -e "2. \033[1;32m644\033[0m - Owner: read/write, Group: read, Others: read (Common for text files)"
					echo -e "3. \033[1;32m777\033[0m - Owner: read/write/execute, Group: read/write/execute, Others: read/write/execute (Not recommended for security)"
					echo -e "4. \033[1;32m700\033[0m - Owner: read/write/execute, Group: none, Others: none (For private files)"
					echo -e "5. \033[1;32m600\033[0m - Owner: read/write, Group: none, Others: none (Common for private text files)"
					
					read -p "Enter your choice (1-5): " perms_choice

					case $perms_choice in
						1)
							perms="755"
							;;
						2)
							perms="644"
							;;
						3)
							perms="777"
							;;
						4)
							perms="700"
							;;
						5)
							perms="600"
							;;
						*)
							echo -e "\033[1;31mInvalid choice. Using default permissions 644.\033[0m"
							perms="644"
							;;
					esac

					chmod "$perms" "$file_path"
					echo -e "\033[1;32mPermissions changed to $perms successfully!\033[0m"
					;;

            8)
                # Create Directory action
                read -p "Enter the directory path to create: " dir_path
                if [ -e "$dir_path" ]; then
                    echo -e "\033[1;31mError: Directory already exists.\033[0m"
                    continue
                fi
                mkdir -p "$dir_path"
                echo -e "\033[1;32mDirectory '$dir_path' created successfully!\033[0m"
                ;;
            9)
                # View File Content action
                read -p "Enter the file path to view: " file_path
                if [ ! -f "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist or is not a valid file.\033[0m"
                    continue
                fi
                cat "$file_path"
                ;;
            10)
                # Search for File by Name action
                read -p "Enter the filename to search for: " file_name
                read -p "Enter the directory to search in: " search_dir
                find "$search_dir" -name "$file_name"
                ;;
            11)
                # Check Disk Usage action
                read -p "Enter the file or directory path to check disk usage: " path
                du -sh "$path"
                ;;
            12)
                # Change Ownership action
                read -p "Enter the file or directory path: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                read -p "Enter the new owner: " owner
                chown "$owner" "$file_path"
                echo -e "\033[1;32mOwnership changed successfully!\033[0m"
                ;;
            13)
                # Change File Group action
                read -p "Enter the file or directory path: " file_path
                if [ ! -e "$file_path" ]; then
                    echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
                    continue
                fi
                read -p "Enter the new group: " group
                chgrp "$group" "$file_path"
                echo -e "\033[1;32mGroup changed successfully!\033[0m"
                ;;
                
            14)
				# Convert DOS to Unix action
				if ! command -v dos2unix &> /dev/null; then
					echo -e "\033[1;31mError: 'dos2unix' is not installed.\033[0m"
					echo -e "\033[1;33mWould you like to install 'dos2unix'? (yes/no)\033[0m"
					read -p "Enter your choice: " install_choice
					if [[ "$install_choice" == "yes" || "$install_choice" == "y" ]]; then
						sudo apt-get install dos2unix -y
						if [ $? -eq 0 ]; then
							echo -e "\033[1;32m'dos2unix' installed successfully!\033[0m"
						else
							echo -e "\033[1;31mFailed to install 'dos2unix'. Please check your package manager.\033[0m"
							continue
						fi
					else
						echo -e "\033[1;31mCannot proceed without 'dos2unix'. Exiting...\033[0m"
						continue
					fi
				fi

				read -p "Enter the file path to convert from DOS to Unix: " file_path
				if [ ! -e "$file_path" ]; then
					echo -e "\033[1;31mError: '$file_path' does not exist.\033[0m"
					continue
				fi

				# Use dos2unix to convert the file
				dos2unix "$file_path"
				if [ $? -eq 0 ]; then
					echo -e "\033[1;32mFile '$file_path' successfully converted from DOS to Unix format!\033[0m"
				else
					echo -e "\033[1;31mError: Failed to convert '$file_path'.\033[0m"
				fi
				;;
			
			15)

					# Find big files action
					read -p "Enter the minimum file size in MB to search for (e.g., 100 for 100MB): " size_in_mb
					if ! [[ "$size_in_mb" =~ ^[0-9]+$ ]]; then
						echo -e "\033[1;31mError: Please enter a valid number.\033[0m"
						continue
					fi

					# Ask for directory to search (optional)
					read -p "Enter the directory to search in (default is root '/'): " search_dir
					if [ -z "$search_dir" ]; then
						search_dir="/"
					fi

					# Ask for file type to filter (optional)
					read -p "Enter file extension to filter by (e.g., .log, .txt, leave empty to search all files): " file_ext
					if [ -z "$file_ext" ]; then
						file_ext="*"
					fi

					# Find files greater than the specified size in MB and match the file type
					echo -e "\033[1;33mSearching for files larger than $size_in_mb MB in '$search_dir' with extension '$file_ext'...\033[0m"
					find "$search_dir" -type f -name "$file_ext" -size +"$((size_in_mb * 1024))"k -exec ls -lh {} \; | awk '{ print $9 ": " $5 }'

					echo -e "\033[1;32mSearch completed.\033[0m"
					;;



            0)
                # Return to Main Menu
                echo -e "\033[1;33mReturning to the main menu...\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please select 0-13.\033[0m"
                continue
                ;;
        esac

        # Prompt to press Enter to return to the menu
        echo -e "\n\033[1;33mPress Enter to return to the menu...\033[0m"
        read
        clear
    done
}
file_management
