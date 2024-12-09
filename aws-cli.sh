

manage_aws_cli() {
echo -e "\n\033[1;34m=============================\033[0m"
echo -e "\033[1;34m  AWS CLI Management Menu  \033[0m"
echo -e "\033[1;34m=============================\033[0m"
echo -e "\033[1;32m1.\033[0m Check AWS CLI Installation"
echo -e "\033[1;32m2.\033[0m Display Current AWS CLI Configuration"
echo -e "\033[1;32m3.\033[0m Update AWS CLI"
echo -e "\033[1;32m4.\033[0m Test AWS CLI Connection"
echo -e "\033[1;32m5.\033[0m Configure New AWS CLI Profile"
echo -e "\033[1;32m6.\033[0m Manage AWS CLI Profiles"
echo -e "\033[1;32m7.\033[0m Manage EC2 Instances"
echo -e "\033[1;32m8.\033[0m Manage Lightsail Instances"
echo -e "\033[1;32m9.\033[0m Install AWS CLI"
echo -e "\033[1;32m10.\033[0m Return to Main Menu"
echo -e "\033[1;34m=============================\033[0m"

    
    read -p "Select an option (1-10): " choice

    case $choice in
        1)
            if command -v aws &> /dev/null; then
                echo -e "\033[1;32mAWS CLI is installed.\033[0m"
            else
                echo -e "\033[1;31mAWS CLI is not installed.\033[0m"
            fi
            read -p "Press Enter to continue..." 
            manage_aws_cli
            ;;
        2)
            echo -e "\033[1;34mCurrent AWS CLI Configuration (Reading from /root/.aws/credentials and /root/.aws/config):\033[0m"
            
            # Check for credentials file and display it
            if [ -f /root/.aws/credentials ]; then
                echo -e "\033[1;32mCredentials:\033[0m"
                echo -e "\033[1;33m---------------------------\033[0m"
                cat /root/.aws/credentials | sed 's/aws_access_key_id/AWS Access Key ID/' | sed 's/aws_secret_access_key/AWS Secret Access Key/'
                echo -e "\033[1;33m---------------------------\033[0m"
            else
                echo -e "\033[1;31mNo credentials file found.\033[0m"
            fi
            
            # Check for config file and display it
            if [ -f /root/.aws/config ]; then
                echo -e "\033[1;32mConfig:\033[0m"
                echo -e "\033[1;33m---------------------------\033[0m"
                cat /root/.aws/config | sed 's/region/AWS Region/' | sed 's/output/AWS Output Format/'
                echo -e "\033[1;33m---------------------------\033[0m"
            else
                echo -e "\033[1;31mNo config file found.\033[0m"
            fi
            read -p "Press Enter to continue..." 

            manage_aws_cli
            ;;
        3)
            echo "Updating AWS CLI..."
            sudo apt-get update && sudo apt-get install --only-upgrade awscli
            read -p "Press Enter to continue..." 
            manage_aws_cli
            ;;
        4)
            echo "Testing AWS CLI connection using profile from /root/.aws/credentials..."
            select_aws_profile
            aws sts get-caller-identity --profile "$AWS_PROFILE"
            read -p "Press Enter to continue..." 
            manage_aws_cli
            ;;
        5)
            configure_aws_profile
            ;;
        6)
            manage_aws_profiles
            ;;
        7)
            select_aws_profile_for_ec2
            ;;
        8)
            select_aws_profile_for_lightsail
            ;;
        9)
            echo "Installing AWS CLI..."
            if ! command -v aws &> /dev/null; then
                echo "Installing required packages..."
                sudo apt install curl unzip -y

                echo "Downloading AWS CLI v2..."
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                
                echo "Unzipping AWS CLI v2..."
                unzip awscliv2.zip

                echo "Installing AWS CLI v2..."
                sudo ./aws/install

                echo "Verifying installation..."
                aws --version
                echo -e "\033[1;32mAWS CLI has been installed successfully.\033[0m"
            else
                echo -e "\033[1;32mAWS CLI is already installed.\033[0m"
            fi
            read -p "Press Enter to continue..." 
            manage_aws_cli
            ;;
        10)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            manage_aws_cli
            ;;
    esac
}




# Function to configure AWS CLI profile
configure_aws_profile() {
    echo -e "\033[1;34mConfigure AWS CLI Profile\033[0m"
    read -p "Enter the profile name: " profile_name
    read -p "Enter AWS Access Key ID: " aws_access_key
    read -p "Enter AWS Secret Access Key: " aws_secret_key

    # Default values to display
    default_region="me-south-1"
    default_output="table"

    # Prompt for region and enforce input
    while true; do
        read -p "Enter Default region (e.g., $default_region): " aws_region
        if [[ -n "$aws_region" ]]; then
            break
        else
            echo -e "\033[1;31mRegion cannot be empty. Please enter a value.\033[0m"
        fi
    done

    # Prompt for output format and enforce input
    while true; do
        read -p "Enter Default output format (json, text, table) [e.g., $default_output]: " aws_output
        if [[ "$aws_output" =~ ^(json|text|table)$ ]]; then
            break
        else
            echo -e "\033[1;31mInvalid output format. Please enter 'json', 'text', or 'table'.\033[0m"
        fi
    done

    # Configure AWS CLI profile
    aws configure set aws_access_key_id "$aws_access_key" --profile "$profile_name"
    aws configure set aws_secret_access_key "$aws_secret_key" --profile "$profile_name"
    aws configure set region "$aws_region" --profile "$profile_name"
    aws configure set output "$aws_output" --profile "$profile_name"
    
    echo -e "\033[1;32mAWS CLI profile '$profile_name' has been configured successfully.\033[0m"
    read -p "Press Enter to continue..." 
    manage_aws_cli
}


manage_aws_profiles() {
echo -e "\n\033[1;34m===============================\033[0m"
echo -e "\033[1;34m AWS CLI Profile Management \033[0m"
echo -e "\033[1;34m===============================\033[0m"
echo -e "\033[1;32m1.\033[0m View AWS Profiles"
echo -e "\033[1;32m2.\033[0m Select and Use AWS Profile"
echo -e "\033[1;32m3.\033[0m Edit AWS Profile"
echo -e "\033[1;32m4.\033[0m Remove AWS Profile"
echo -e "\033[1;32m5.\033[0m Return to Main Menu"
echo -e "\033[1;34m===============================\033[0m"


    read -p "Select an option (1-5): " choice

    case $choice in
        1)
            view_aws_profiles
            ;;
        2)
            select_aws_profile
            ;;
        3)
            edit_aws_profile
            ;;
        4)
            remove_aws_profile
            ;;
        5)
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            manage_aws_profiles
            ;;
    esac
}

view_aws_profiles() {
    echo -e "\033[1;34mAvailable AWS CLI Profiles\033[0m"

    # Get the list of AWS profiles
    profiles=$(aws configure list-profiles)

    # Check if there are any profiles
    if [[ -z "$profiles" ]]; then
        echo -e "\033[1;31mNo AWS CLI profiles found.\033[0m"
        return
    fi

    # Display profiles
    echo "$profiles"
    read -p "Press Enter to continue..." 
    
}

select_aws_profile() {
    echo -e "\033[1;34mSelect an AWS CLI Profile\033[0m"

    # Get the list of AWS profiles
    profiles=$(aws configure list-profiles)

    # Check if there are any profiles
    if [[ -z "$profiles" ]]; then
        echo -e "\033[1;31mNo AWS CLI profiles found.\033[0m"
        return
    fi

    # Display profiles as selectable options
    select profile_name in $profiles; do
        if [[ -n "$profile_name" ]]; then
            echo -e "\033[1;32mYou selected profile '$profile_name'.\033[0m"
            export AWS_PROFILE="$profile_name"
            break
        else
            echo -e "\033[1;31mInvalid selection, please try again.\033[0m"
        fi
    done
}

edit_aws_profile() {
    echo -e "\033[1;34mEdit AWS CLI Profile\033[0m"

    # Get the list of AWS profiles
    profiles=$(aws configure list-profiles)

    # Check if there are any profiles
    if [[ -z "$profiles" ]]; then
        echo -e "\033[1;31mNo AWS CLI profiles found.\033[0m"
        return
    fi

    # Display profiles and prompt for selection
    echo "Available profiles:"
    select profile_name in $profiles; do
        if [[ -n "$profile_name" ]]; then
            echo -e "\033[1;32mYou selected profile '$profile_name'.\033[0m"
            break
        else
            echo -e "\033[1;31mInvalid selection, please try again.\033[0m"
        fi
    done

    # Prompt for new values (access key, secret key, region, output format)
    echo "Editing profile '$profile_name'. Please enter new values or press Enter to keep current settings."
    read -p "AWS Access Key ID [current: $(aws configure get aws_access_key_id --profile "$profile_name")]: " new_aws_access_key_id
    read -p "AWS Secret Access Key [current: $(aws configure get aws_secret_access_key --profile "$profile_name")]: " new_aws_secret_access_key
    read -p "AWS Region [current: $(aws configure get region --profile "$profile_name")]: " new_region
    read -p "Output Format [current: $(aws configure get output --profile "$profile_name")]: " new_output_format

    # Update the profile with new values (if provided)
    aws configure set aws_access_key_id "$new_aws_access_key_id" --profile "$profile_name" 
    aws configure set aws_secret_access_key "$new_aws_secret_access_key" --profile "$profile_name"
    aws configure set region "$new_region" --profile "$profile_name"
    aws configure set output "$new_output_format" --profile "$profile_name"

    echo -e "\033[1;32mProfile '$profile_name' updated successfully.\033[0m"
    read -p "Press Enter to continue..." 
}

remove_aws_profile() {
    echo -e "\033[1;34mRemove AWS CLI Profile\033[0m"

    # Get the list of AWS profiles
    profiles=$(aws configure list-profiles)

    # Check if there are any profiles
    if [[ -z "$profiles" ]]; then
        echo -e "\033[1;31mNo AWS CLI profiles found.\033[0m"
        return
    fi

    # Display profiles and prompt for selection
    echo "Available profiles:"
    select profile_name in $profiles; do
        if [[ -n "$profile_name" ]]; then
            echo -e "\033[1;32mYou selected profile '$profile_name'.\033[0m"
            break
        else
            echo -e "\033[1;31mInvalid selection, please try again.\033[0m"
        fi
    done

    # Prompt for confirmation
    read -p "Are you sure you want to remove profile '$profile_name'? (y/n): " confirmation
    if [[ "$confirmation" == "y" || "$confirmation" == "Y" ]]; then
        # Remove the selected profile from credentials and config files
        sed -i "/^\[$profile_name\]/,/^\[.*\]/d" /root/.aws/credentials
        sed -i "/^\[profile $profile_name\]/,/^\[.*\]/d" /root/.aws/config

        echo -e "\033[1;32mProfile '$profile_name' removed successfully.\033[0m"
    else
        echo -e "\033[1;33mProfile removal canceled.\033[0m"
    fi
    read -p "Press Enter to continue..." 
}



select_aws_profile_for_ec2() {
    echo -e "\033[1;34mSelect AWS CLI Profile for EC2 Management\033[0m"
    select_aws_profile
    select_ec2_region
    manage_ec2_instances
}

select_aws_profile_for_lightsail() {
    echo -e "\033[1;34mSelect AWS CLI Profile for Lightsail Management\033[0m"
    select_aws_profile
    select_lightsail_region
    manage_lightsail_instances
}
select_ec2_region() {
    echo -e "\033[1;34mSelect AWS EC2 Region by City:\033[0m"
    
    # List of all available AWS EC2 regions
    regions=(
        "ap-south-1"        "eu-west-2"        "ap-northeast-2"  "ca-central-1"    "eu-central-1"    "us-east-2"
        "eu-north-1"        "eu-south-2"       "me-south-1"      "sa-east-1"       "eu-central-2"    "us-west-1"
        "eu-west-3"         "eu-west-1"        "ap-northeast-1"  "ap-southeast-1"  "ap-southeast-4"  "us-west-2"
        "eu-south-1"        "ap-northeast-3"   "me-central-1"    "ap-southeast-2"  "us-east-1"
    )
    
    # Map regions to cities
    declare -A region_city_map
    region_city_map=(
        ["ap-south-1"]="Mumbai, India"
        ["eu-west-2"]="London, United Kingdom"
        ["ap-northeast-2"]="Seoul, South Korea"
        ["ca-central-1"]="Central Canada (Montreal)"
        ["eu-central-1"]="Frankfurt, Germany"
        ["us-east-2"]="Ohio, United States"
        ["eu-north-1"]="Stockholm, Sweden"
        ["eu-south-2"]="Milan, Italy"
        ["me-south-1"]="Bahrain"
        ["sa-east-1"]="São Paulo, Brazil"
        ["eu-central-2"]="Warsaw, Poland"
        ["us-west-1"]="Northern California, United States"
        ["eu-west-3"]="Paris, France"
        ["eu-west-1"]="Ireland"
        ["ap-northeast-1"]="Tokyo, Japan"
        ["ap-southeast-1"]="Singapore"
        ["ap-southeast-4"]="Jakarta, Indonesia"
        ["us-west-2"]="Oregon, United States"
        ["eu-south-1"]="Milan, Italy"
        ["ap-northeast-3"]="Osaka, Japan"
        ["me-central-1"]="United Arab Emirates"
        ["ap-southeast-2"]="Sydney, Australia"
        ["us-east-1"]="North Virginia, United States"
    )
    
    # Display cities to the user with a numbered list
    cities=()
    for region in "${regions[@]}"; do
        cities+=("${region_city_map[$region]} ($region)")
    done
    
    PS3="Select a city: "
    select city in "${cities[@]}"; do
        if [[ -n "$city" ]]; then
            # Extract region code from the selected city
            selected_region=$(echo "$city" | awk -F ' ' '{print $NF}' | tr -d '()')
            echo "You selected region: $selected_region ($city)"
            break
        else
            echo -e "\033[1;31mInvalid selection, defaulting to region 'eu-central-1'.\033[0m"
            selected_region="eu-central-1"  # Default region
            echo "You selected region: $selected_region (${region_city_map[$selected_region]})"
            break
        fi
    done

    # Save the selected region to a file
    region_file="/root/aws/ec2.region.txt"
    echo "$selected_region" > "$region_file"
    echo "Region saved to $region_file"

    # Return the selected region and city
    echo "$selected_region"
    echo "${region_city_map[$selected_region]}"
}


manage_ec2_instances() {
    # Read the region from the saved file
    region_file="/root/aws/ec2.region.txt"
    if [[ -f "$region_file" ]]; then
        region=$(cat "$region_file")
    else
        echo -e "\033[1;31mRegion file not found. Please select a region first.\033[0m"
        return
    fi

echo -e "\n\033[1;34m===============================\033[0m"
echo -e "\033[1;34m    EC2 Instance Management    \033[0m"
echo -e "\033[1;34m===============================\033[0m"
echo -e "\033[1;33mCurrent Region:\033[0m \033[1;32m$region\033[0m"
echo -e "\n\033[1;34mSelect an EC2 Management Task:\033[0m"
echo -e "\033[1;32m1.\033[0m List EC2 Instances"
echo -e "\033[1;32m2.\033[0m Start EC2 Instance"
echo -e "\033[1;32m3.\033[0m Stop EC2 Instance"
echo -e "\033[1;32m4.\033[0m Terminate EC2 Instance"
echo -e "\033[1;32m5.\033[0m Describe EC2 Instance"
echo -e "\033[1;32m6.\033[0m Return to AWS CLI Management Menu"
echo -e "\033[1;34m===============================\033[0m"


    read -p "Select an option (1-6): " ec2_choice

    case $ec2_choice in
        1)
            echo -e "\033[1;32mListing EC2 Instances in region: $region\033[0m"
            aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$region" --query 'Reservations[*].Instances[*].InstanceId' --output table > /root/aws/list-ec2-instances-$region.txt
            cat /root/aws/list-ec2-instances-$region.txt
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
        2)
            echo "Enter the Instance ID to start:"
            read instance_id
            echo "Starting EC2 Instance $instance_id in region $region..."
            aws ec2 start-instances --profile "$AWS_PROFILE" --region "$region" --instance-ids "$instance_id" > /root/aws/start-ec2-instance-$region.txt
            cat /root/aws/start-ec2-instance-$region.txt
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
        3)
            echo "Enter the Instance ID to stop:"
            read instance_id
            echo "Stopping EC2 Instance $instance_id in region $region..."
            aws ec2 stop-instances --profile "$AWS_PROFILE" --region "$region" --instance-ids "$instance_id" > /root/aws/stop-ec2-instance-$region.txt
            cat /root/aws/stop-ec2-instance-$region.txt
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
        4)
            echo "Enter the Instance ID to terminate:"
            read instance_id
            echo "Terminating EC2 Instance $instance_id in region $region..."
            aws ec2 terminate-instances --profile "$AWS_PROFILE" --region "$region" --instance-ids "$instance_id" > /root/aws/terminate-ec2-instance-$region.txt
            cat /root/aws/terminate-ec2-instance-$region.txt
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
        5)
            echo "Enter the Instance ID to describe:"
            read instance_id
            echo "Describing EC2 Instance $instance_id in region $region..."
            aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$region" --instance-ids "$instance_id" --output table > /root/aws/describe-ec2-instance-$region.txt
            cat /root/aws/describe-ec2-instance-$region.txt
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
        6)
            manage_aws_cli
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            read -p "Press Enter to continue..." 
            manage_ec2_instances
            ;;
    esac
}


select_lightsail_region() {
    echo -e "\033[1;34mSelect AWS Lightsail Region by City:\033[0m"
    
    # List of all available AWS Lightsail regions
    regions=(
        "us-east-1"
        "us-west-1"
        "us-west-2"
        "eu-central-1"
        "eu-west-1"
        "eu-west-2"  # Added UK region
        "ap-southeast-1"
        "ap-northeast-1"
        "ap-south-1"
        "sa-east-1"
        "ca-central-1"
    )
    
    # Map regions to cities
    declare -A region_city_map
    region_city_map=(
        ["us-east-1"]="North Virginia, United States"
        ["us-west-1"]="Northern California, United States"
        ["us-west-2"]="Oregon, United States"
        ["eu-central-1"]="Frankfurt, Germany"
        ["eu-west-1"]="Ireland"
        ["eu-west-2"]="London, United Kingdom"  # Added UK region
        ["ap-southeast-1"]="Singapore"
        ["ap-northeast-1"]="Tokyo, Japan"
        ["ap-south-1"]="Mumbai, India"
        ["sa-east-1"]="São Paulo, Brazil"
        ["ca-central-1"]="Central Canada (Montreal)"
    )
    
    # Display cities to the user with a numbered list
    cities=()
    for region in "${regions[@]}"; do
        cities+=("${region_city_map[$region]} ($region)")
    done
    
    PS3="Select a city: "
    selected_region=""
    select city in "${cities[@]}"; do
        if [[ -n "$city" ]]; then
            # Extract region code from the selected city
            selected_region=$(echo "$city" | awk -F ' ' '{print $NF}' | tr -d '()')
            if [[ -n "${region_city_map[$selected_region]}" ]]; then
                echo -e "\033[1;32mYou selected region: $selected_region (${region_city_map[$selected_region]})\033[0m"
                break
            else
                echo -e "\033[1;31mInvalid selection. Please try again.\033[0m"
            fi
        else
            echo -e "\033[1;31mInvalid selection, defaulting to region 'eu-central-1'.\033[0m"
            selected_region="eu-central-1"  # Default region
            echo -e "\033[1;32mYou selected region: $selected_region (${region_city_map[$selected_region]})\033[0m"
            break
        fi
    done
    
    # Save the selected region to a text file
    if [[ -n "$selected_region" ]]; then
        echo "$selected_region" > /root/aws/lightsail_region.txt
        echo -e "\033[1;33mThe selected region has been saved to 'selected_region.txt'.\033[0m"
    fi
    
    # Return the selected region
    echo "$selected_region"
}


manage_lightsail_instances() {
    # Read the region from the text file
    region_file="/root/aws/lightsail_region.txt"
    if [[ -f "$region_file" ]]; then
        region=$(<"$region_file")
        echo -e "\033[1;34mUsing region: $region\033[0m (from $region_file)"
    else
        echo -e "\033[1;31mRegion file not found. Please select a region first.\033[0m"
        region=$(select_lightsail_region)
    fi

    echo -e "\n\033[1;34m====================================\033[0m"
    echo -e "\033[1;34m   Lightsail Instance Management    \033[0m"
    echo -e "\033[1;34m====================================\033[0m"
    echo -e "\033[1;34mSelect a Lightsail Management Task:\033[0m"
    echo -e "\033[1;32m1.\033[0m  List Lightsail Instances"
    echo -e "\033[1;32m2.\033[0m  Start Lightsail Instance"
    echo -e "\033[1;32m3.\033[0m  Stop Lightsail Instance"
    echo -e "\033[1;32m4.\033[0m  Delete Lightsail Instance"
    echo -e "\033[1;32m5.\033[0m  Describe Lightsail Instance"
    echo -e "\033[1;32m6.\033[0m  Create Lightsail Instance"
    echo -e "\033[1;32m7.\033[0m  Manage SSH Key Pair"
    echo -e "\033[1;32m8.\033[0m  Get Lightsail Instances"
    echo -e "\033[1;32m9.\033[0m  Get Lightsail Bundles"
    echo -e "\033[1;32m10.\033[0m Restart Lightsail Instance"  # Added Restart option
    echo -e "\033[1;32m11.\033[0m Return to AWS CLI Management Menu"
    echo -e "\033[1;34m====================================\033[0m"

    read -p "Select an option (1-11): " lightsail_choice

    case $lightsail_choice in
        1)
            echo "Listing Lightsail Instances in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/list-lightsail-instances-$region.txt"
            aws lightsail get-instances --region "$region" --profile "$AWS_PROFILE" --output table > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        2)
            echo "Enter the Instance Name to start:"
            read instance_name
            echo "Starting Lightsail Instance $instance_name in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/start-lightsail-instance-$instance_name-$region.txt"
            aws lightsail start-instance --region "$region" --profile "$AWS_PROFILE" --instance-name "$instance_name" > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        3)
            echo "Enter the Instance Name to stop:"
            read instance_name
            echo "Stopping Lightsail Instance $instance_name in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/stop-lightsail-instance-$instance_name-$region.txt"
            aws lightsail stop-instance --region "$region" --profile "$AWS_PROFILE" --instance-name "$instance_name" > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        4)
            echo "Enter the Instance Name to delete:"
            read instance_name
            echo "Deleting Lightsail Instance $instance_name in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/delete-lightsail-instance-$instance_name-$region.txt"
            aws lightsail delete-instance --region "$region" --profile "$AWS_PROFILE" --instance-name "$instance_name" > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        5)
            echo "Enter the Instance Name to describe:"
            read instance_name
            echo "Describing Lightsail Instance $instance_name in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/describe-lightsail-instance-$instance_name-$region.txt"
            aws lightsail get-instance --region "$region" --profile "$AWS_PROFILE" --instance-name "$instance_name" --output table > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        6)
            create_lightsail_instance
            ;;
        7)
            manage_lightsail_ssh_key
            ;;
        8)
            echo "Fetching Lightsail Instances in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/get-lightsail-instances-$region.txt"
            aws lightsail get-instances --region "$region" --profile "$AWS_PROFILE" --output table > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        9)
            echo "Fetching Lightsail Bundles in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/get-lightsail-bundles-$region.txt"
            aws lightsail get-bundles --region "$region" --profile "$AWS_PROFILE" --output table > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        10)
            echo "Enter the Instance Name to restart:"
            read instance_name
            echo "Restarting Lightsail Instance $instance_name in region '$region' using profile '$AWS_PROFILE'..."
            output_file="/root/aws/restart-lightsail-instance-$instance_name-$region.txt"
            aws lightsail reboot-instance --region "$region" --profile "$AWS_PROFILE" --instance-name "$instance_name" > "$output_file"
            cat "$output_file"
            read -p "Press Enter to continue..." 
            manage_lightsail_instances
            ;;
        11)
            manage_aws_cli
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            read -p "Press Enter to continue..." 
            ;;
    esac
}


manage_lightsail_ssh_key() {

echo -e "\n\033[1;34m====================================\033[0m"
echo -e "\033[1;34m     Lightsail SSH Key Management    \033[0m"
echo -e "\033[1;34m====================================\033[0m"
echo -e "\033[1;34mSelect an action to manage SSH keys:\033[0m"
echo -e "\033[1;32m1.\033[0m  Create SSH Key Pair"
echo -e "\033[1;32m2.\033[0m  Remove SSH Key Pair"
echo -e "\033[1;32m3.\033[0m  List SSH Key Pairs"
echo -e "\033[1;32m4.\033[0m  View SSH Key Pair Details"
echo -e "\033[1;32m5.\033[0m  Return to Lightsail Instances Management Menu"
echo -e "\033[1;34m====================================\033[0m"


    read -p "Select an option (1-5): " ssh_key_choice

    case $ssh_key_choice in
        1)
            create_lightsail_ssh_key
            ;;
        2)
            remove_lightsail_ssh_key
            ;;
        3)
            list_lightsail_ssh_keys
            ;;
        4)
            view_lightsail_ssh_key_details
            ;;
        5)
            manage_lightsail_instances  # Assuming this is the function that handles Lightsail instance management
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            manage_lightsail_ssh_key
            ;;
    esac
    
}

# Subcategory functions as defined earlier

create_lightsail_ssh_key() {
    selected_region=$(cat /root/aws/lightsail_region.txt)
    echo -e "\033[1;34mCreate Lightsail SSH Key Pair\033[0m"

    # Prompt for SSH key pair name
    read -p "Enter the SSH key pair name: " key_pair_name

    # Run the Lightsail create-key-pair command and save output to file
    echo -e "\033[1;34mCreating SSH key pair '$key_pair_name' in region '$selected_region'...\033[0m"
    output_file="/root/aws/$key_pair_name-create-output.txt"
    aws lightsail create-key-pair \
        --key-pair-name "$key_pair_name" \
        --region "$selected_region" \
        --profile "$AWS_PROFILE" \
        --output table > "$output_file"

    # Check for successful creation
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mSSH key pair '$key_pair_name' created successfully.\033[0m"
        echo "Private key saved to '/root/aws/$key_pair_name.pem'."
    else
        echo -e "\033[1;31mFailed to create SSH key pair.\033[0m"
    fi
    cat "$output_file"
    read -p "Press Enter to continue..." 
    manage_lightsail_ssh_key  # Return to the SSH key management menu
}

remove_lightsail_ssh_key() {
    selected_region=$(cat /root/aws/lightsail_region.txt)
    echo -e "\033[1;34mRemove Lightsail SSH Key Pair\033[0m"

    # Prompt for SSH key pair name
    read -p "Enter the SSH key pair name to remove: " key_pair_name

    # Run the Lightsail delete-key-pair command
    echo -e "\033[1;34mRemoving SSH key pair '$key_pair_name' in region '$selected_region'...\033[0m"
    output_file="/root/aws/$key_pair_name-remove-output.txt"
    aws lightsail delete-key-pair \
        --key-pair-name "$key_pair_name" \
        --region "$selected_region" \
        --profile "$AWS_PROFILE" \
        --output table > "$output_file"

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mSSH key pair '$key_pair_name' removed successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to remove SSH key pair.\033[0m"
    fi
    cat "$output_file"
    read -p "Press Enter to continue..." 
    manage_lightsail_ssh_key  # Return to the SSH key management menu
}

list_lightsail_ssh_keys() {
    selected_region=$(cat /root/aws/lightsail_region.txt)
    echo -e "\033[1;34mListing SSH Key Pairs in Lightsail\033[0m"

    # Run the Lightsail get-key-pairs command
    output_file="/root/aws/key-pairs-list-output.txt"
    aws lightsail get-key-pairs \
        --region "$selected_region" \
        --profile "$AWS_PROFILE" \
        --output table > "$output_file"

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mSSH key pairs listed successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to list SSH key pairs.\033[0m"
    fi
    cat "$output_file"
    read -p "Press Enter to continue..." 
    manage_lightsail_ssh_key  # Return to the SSH key management menu
}

view_lightsail_ssh_key_details() {
    selected_region=$(cat /root/aws/lightsail_region.txt)
    echo -e "\033[1;34mView SSH Key Pair Details\033[0m"

    # Prompt for SSH key pair name
    read -p "Enter the SSH key pair name to view details: " key_pair_name

    # Run the Lightsail get-key-pairs command for details
    output_file="/root/aws/$key_pair_name-details-output.txt"
    aws lightsail get-key-pairs \
        --region "$selected_region" \
        --profile "$AWS_PROFILE" \
        --output table > "$output_file"

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mDetails retrieved successfully for '$key_pair_name'.\033[0m"
    else
        echo -e "\033[1;31mFailed to retrieve details. Check the key name and try again.\033[0m"
    fi
    cat "$output_file"
    read -p "Press Enter to continue..." 
    manage_lightsail_ssh_key  # Return to the SSH key management menu
}



create_lightsail_instance() {
    selected_region=$(select_lightsail_region)
    echo -e "\033[1;34mCreate Lightsail Instance\033[0m"
    echo "Enter the following details to create a new Lightsail instance."

    # Prompt for instance name
    read -p "Enter the instance name: " instance_name

    # Prompt for SSH key pair name
    read -p "Enter the SSH key pair name: " ssh_key

    # Prompt for blueprint ID (Ubuntu version)
    echo "Available blueprints:"
    echo "1. ubuntu_22_04"
    echo "2. amazon_linux_2"
    echo "3. centos_8"
    read -p "Enter the blueprint ID (1-3): " blueprint_choice
    case $blueprint_choice in
        1) blueprint_id="ubuntu_22_04" ;;
        2) blueprint_id="amazon_linux_2" ;;
        3) blueprint_id="centos_8" ;;
        *)
            echo -e "\033[1;31mInvalid choice, defaulting to 'ubuntu_22_04'.\033[0m"
            blueprint_id="ubuntu_22_04"
            ;;
    esac

    # Prompt for bundle ID (instance size)
    echo "Available bundles:"
    echo "1. micro_3_0 (1 GB RAM, 2 vCPU)"
    echo "2. nano_3_0 (512 MB RAM, 2 vCPU)"
    echo "3. small_3_0 (2 GB RAM, 2 vCPU)"
    read -p "Enter the bundle ID (1-3): " bundle_choice
    case $bundle_choice in
        1) bundle_id="micro_3_0" ;;
        2) bundle_id="nano_3_0" ;;
        3) bundle_id="small_3_0" ;;
        *)
            echo -e "\033[1;31mInvalid choice, defaulting to 'micro_3_0'.\033[0m"
            bundle_id="micro_3_0"
            ;;
    esac

    # Run the Lightsail instance creation command
    echo -e "\033[1;34mCreating Lightsail instance '$instance_name' in region '$selected_region'...\033[0m"
    output_file="/root/aws/create-lightsail-instance.txt"
    aws lightsail create-instances \
        --instance-names "$instance_name" \
        --availability-zone "${selected_region}a" \
        --blueprint-id "$blueprint_id" \
        --bundle-id "$bundle_id" \
        --key-pair-name "$ssh_key" \
        --profile "$AWS_PROFILE" \
        --output table > "$output_file"

    # Display the output
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mInstance '$instance_name' created successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to create instance. Check logs for details.\033[0m"
    fi
    cat "$output_file"
    read -p "Press Enter to continue..." 
    manage_lightsail_instances
}




manage_aws_cli
