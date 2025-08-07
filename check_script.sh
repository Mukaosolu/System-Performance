#!/bin/bash

CONFIG_FILE="/c/Users/mukaosolu.chukwuonwe/SystemAlert/config.txt"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Ensure API_URL is set
if [[ -z "$API_URL" ]]; then
    echo "Error: API_URL is not set in the config file."
    exit 1
fi

# Define drive paths for the local machine
C_DRIVE="/c"
F_DRIVE="/f"

# Define log file
LOG_FILE="system_check.log"

# Define API URL
API_URL=$API_URL

# HTML template file
HTML_TEMPLATE_FILE="/c/Users/mukaosolu.chukwuonwe/SystemAlert/$HTML_TEMPLATE_FILE"

if [ ! -f "$HTML_TEMPLATE_FILE" ]; then
    echo "Error: HTML template file not found at $HTML_TEMPLATE_FILE"
    exit 1
else
    echo "✅ HTML template found at $HTML_TEMPLATE_FILE"
fi

# Get server name (without extra spaces)
SERVER_NAME=$(hostname)

# Get the primary IP address using ipconfig (Windows-specific), trimming spaces
SERVER_IP=$(ipconfig | grep -A 10 "Ethernet" | grep "IPv4 Address" | awk -F: '{print $2}' | tr -d '\r' | head -n 1 | xargs)

# Replace the placeholders and output to the console
echo "Server Name: $SERVER_NAME"
echo "Server IP:  $SERVER_IP"


# Threshold percentage
THRESHOLD=$THRESHOLD

# Function to log messages
log_and_print() {
    local message="$1"
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Rotate log file if size exceeds 1MB
rotate_log_file() {
    local max_size=1048576 # 1 MB
    if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -gt "$max_size" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.bak"
        log_and_print "Log file rotated."
    fi
}


# Function to check if a metric exceeds the threshold
check_threshold_exceeded() {
    local usage="$1"
    local metric_name="$2"


  # Convert usage and threshold to integers by truncating decimals
    local usage_int=${usage%.*}    # Remove everything after the decimal point
    local threshold_int=${THRESHOLD%.*}


    if [[ -z "$THRESHOLD" || -z "$usage_int" ]]; then
    log_and_print "Error: Threshold or usage value is empty. Threshold: '$THRESHOLD', Usage: '$usage_int'"
    return 1
    
    fi

       if (( usage_int > threshold_int )); then
        log_and_print "Alert: $metric_name exceeds $THRESHOLD% (Current: $usage%)."
        return 0
    fi
    return 1

}


# Function to check drive usage locally
check_drive_usage() {
    local drive_path=$1
    local drive_label=$2

    if [ ! -d "$drive_path" ]; then
        log_and_print "Error: Drive path $drive_path does not exist."
        echo "{\"drive\":\"$drive_label\", \"status\":\"error\"}"
        return
    fi

    total_space=$(df -h "$drive_path" | awk 'NR==2 {print $2}')
    used_space=$(df -h "$drive_path" | awk 'NR==2 {print $3}')
    available_space=$(df -h "$drive_path" | awk 'NR==2 {print $4}')
    usage_percentage=$(df -h "$drive_path" | awk 'NR==2 {print $5}' | tr -d '%')

    log_and_print "Local Drive: $drive_label"
    log_and_print "  Total Space: $total_space"
    log_and_print "  Used Space: $used_space"
    log_and_print "  Available Space: $available_space"
    log_and_print "  Usage Percentage: $usage_percentage%"

    echo "{\"drive\":\"$drive_label\", \"total\":\"$total_space\", \"used\":\"$used_space\", \"available\":\"$available_space\", \"usage_percentage\":\"$usage_percentage\", \"exceeded\":$( [ "$usage_percentage" -gt 15 ] && echo true || echo false )}"
}

# Function to fetch and send system data
send_system_data_and_notifications() {
    log_and_print "Fetching system data..."

    # CPU and Memory data
    cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2 + $4) / ($2 + $4 + $5) * 100} END {print usage}')
    total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    free_memory=$(grep MemFree /proc/meminfo | awk '{print $2}')
    used_memory=$(($total_memory - $free_memory))
    memory_usage_percentage=$(awk "BEGIN {printf \"%.2f\", ($used_memory / $total_memory) * 100}")
    total_memory_gb=$(awk "BEGIN {printf \"%.2f\", $total_memory / 1024 / 1024}")


    
    if check_threshold_exceeded "$cpu_usage" "CPU Usage"; then
        cpu_exceeded=0
    else
        cpu_exceeded=1
    fi

    if check_threshold_exceeded "$memory_usage_percentage" "Memory Usage"; then
        memory_exceeded=0
    else
        memory_exceeded=1
    fi

    

    # Fetch C drive data
    if [ ! -d "$C_DRIVE" ]; then
        log_and_print "Error: C Drive path ($C_DRIVE) does not exist."
        exit 1
    fi

    c_drive_total=$(df --output=size "$C_DRIVE" | tail -n 1)
    c_drive_used=$(df --output=used "$C_DRIVE" | tail -n 1)
    c_drive_available=$(df --output=avail "$C_DRIVE" | tail -n 1)
    c_drive_usage_percentage=$(df --output=pcent "$C_DRIVE" | tail -n 1 | tr -d '%')

    c_drive_total_gb=$(awk "BEGIN {printf \"%.2f\", $c_drive_total / 1024 / 1024}")
    c_drive_used_gb=$(awk "BEGIN {printf \"%.2f\", $c_drive_used / 1024 / 1024}")
    c_drive_available_gb=$(awk "BEGIN {printf \"%.2f\", $c_drive_available / 1024 / 1024}")
    c_drive_exceeded=$(check_threshold_exceeded "$c_drive_usage_percentage" "C Drive Usage")

    c_drive_usage_percentage=$(df --output=pcent "$C_DRIVE" | tail -n 1 | tr -d '%')
    if check_threshold_exceeded "$c_drive_usage_percentage" "C Drive Usage"; then
        c_drive_exceeded=0
    else
        c_drive_exceeded=1
    fi

    
    log_and_print "C Drive Usage Percentage: ${c_drive_usage_percentage}%"

    
    # Fetch F drive data
if [ ! -d "$F_DRIVE" ]; then
    log_and_print "Error: F Drive path ($F_DRIVE) does not exist."
else
    f_drive_total=$(df --output=size "$F_DRIVE" | tail -n 1)
    f_drive_used=$(df --output=used "$F_DRIVE" | tail -n 1)
    f_drive_available=$(df --output=avail "$F_DRIVE" | tail -n 1)
    f_drive_usage_percentage=$(df --output=pcent "$F_DRIVE" | tail -n 1 | tr -d '%')
    

    f_drive_total_gb=$(awk "BEGIN {printf \"%.2f\", $f_drive_total / 1024 / 1024}")
    f_drive_used_gb=$(awk "BEGIN {printf \"%.2f\", $f_drive_used / 1024 / 1024}")
    f_drive_available_gb=$(awk "BEGIN {printf \"%.2f\", $f_drive_available / 1024 / 1024}")

    f_drive_exceeded=$(check_threshold_exceeded "$f_drive_usage_percentage" "F Drive Usage")

    f_drive_usage_percentage=$(df --output=pcent "$F_DRIVE" | tail -n 1 | tr -d '%')
    if check_threshold_exceeded "$f_drive_usage_percentage" "F Drive Usage"; then
        f_drive_exceeded=0
    else
        f_drive_exceeded=1
    fi
    
    log_and_print "F Drive Usage Percentage: ${f_drive_usage_percentage}%"
fi


# Check if any condition exceeded
    if [[ $cpu_exceeded -eq 0 || $memory_exceeded -eq 0 || $c_drive_exceeded -eq 0 || $f_drive_exceeded -eq 0 ]]; then
    log_and_print "One or more metrics exceeded the threshold."

    # Get current hour (24-hour format)
    current_hour=$(date +'%H')

    # Silence emails from 12:00 AM (00) to 4:59 AM (04)
    if [[ "$current_hour" -ge 0 && "$current_hour" -lt 5 ]]; then
        log_and_print "Email notifications are silenced between 12:00 AM and 5:00 AM. Skipping email send."
        return
    else
        log_and_print "Preparing to send email."
    fi


    # Check if the HTML template file exists
    if [ ! -f "$HTML_TEMPLATE_FILE" ]; then
        log_and_print "Error: HTML template file not found."
        exit 1
    fi

     HTML_BODY=$(<"$HTML_TEMPLATE_FILE")
     
# Initialize the warning banner message 
warning_banner=""
base64_icon="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAABy0lEQVR4nNWUz0tUURTHb1EGkoEz9/u9IyhUzELGZQvThUUQRAQJYRDRJgJd6VqaEquNrtR+/AVBy1pVtpg20SY3gSBM8c55Sou2tTFaPDnPmVCbN6OzqgtfuI/3zud97z3fe53778e3np5Oyef7TTbfd2Hi3OHI+3P1ZyFHFagI+VvJxJTOgUpEXt3x3ZDV/gUU4KGS99by+S4FXtUhmQJefgeOK1kW4MFuGHlWydfVYvGYAu8bAJZr2gutpDXkmyiEwZ3u3mmhUFJyppGb2Pszpgy35TiEAfthCvvS3d2n5NtqLndCyJ9tAH/Ulr68kcv1OiXvqPeTMTCWtV8tgIkC12JySry/7RR4JMClWlPaAgowK95fTpsj5BNrvZCP2waSS3VGGhejW2SaOFgQcrFJjMoawhVzag5vCHk3Ji+2zF6WQrig5P3Y++vuawgU8sNqqdQh5EajgogcN2U0ZH3FuaMKfKwWCkijo8CLyPsRBW5lAYWcyHB4U0I4L8DzP8FeB4pCfkqcO6LkswMs96nVWG1Mnt51/BQYtpeJc4dsTxX41SR3mwJM27eJmQCGW94+GsIpIecV+GwnKD1F2/M5CeHkvq+xf25sAc0q1ST00PI3AAAAAElFTkSuQmCC"

# Generate warning message if metrics are exceeded
if [[ $cpu_exceeded -eq 0 ]]; then
    warning_banner+="<p><img src=\"$base64_icon\" alt=\"CPU Usage Warning\"> Warning: <b>CPU USAGE</b> has exceeded the threshold at <b>${cpu_usage}%</b>. Please reduce CPU load to avoid performance issues.</p>"
fi
if [[ $memory_exceeded -eq 0 ]]; then
    warning_banner+="<p><img src=\"$base64_icon\" alt=\"CPU Usage Warning\"> Warning: <b>MEMORY USAGE</b> has exceeded the threshold at <b>${memory_usage_percentage}%</b>. Please optimize memory usage to avoid performance issues.</p>"
fi
if [[ $c_drive_exceeded -eq 0 ]]; then
    warning_banner+="<p><img src=\"$base64_icon\" alt=\"CPU Usage Warning\"> Warning: <b>C DRIVE USAGE</b> has exceeded the threshold at <b>${c_drive_usage_percentage}%</b>. Please free up space to avoid performance issues.</p>"
fi
if [[ $f_drive_exceeded -eq 0 && -d "$F_DRIVE" ]]; then
    warning_banner+="<p><img src=\"$base64_icon\" alt=\"CPU Usage Warning\"> Warning: <b>F DRIVE USAGE</b> has exceeded the threshold at <b>${f_drive_usage_percentage}%</b>. Please free up space to avoid performance issues.</p>"
fi

# Default message if no warnings
if [ -z "$warning_banner" ]; then
    warning_banner="<p>All metrics are within the acceptable range. No immediate action is required.</p>"
fi

    # Replace placeholders in the HTML with actual data, using '|' as the delimiter
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{cpu-usage}}|${cpu_usage}%|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{total-memory}}|${total_memory_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{memory-usage}}|${memory_usage_percentage}%|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{c-drive-total}}|${c_drive_total_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{c-drive-used}}|${c_drive_used_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{c-drive-available}}|${c_drive_available_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{c-drive-usage}}|${c_drive_usage_percentage}%|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{f-drive-total}}|${f_drive_total_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{f-drive-used}}|${f_drive_used_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{f-drive-available}}|${f_drive_available_gb} GB|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{f-drive-usage}}|${f_drive_usage_percentage}%|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{exceeded-metrics}}|${exceeded_metrics}|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{warning-banner}}|${warning_banner}|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{SERVER_NAME}}|${SERVER_NAME}|g")
HTML_BODY=$(echo "$HTML_BODY" | sed "s|{{SERVER_IP}}|${SERVER_IP}|g")



    # Escape special characters for embedding the HTML content
    ESCAPED_HTML_BODY=$(echo "$HTML_BODY" | sed 's/"/\\"/g' | tr -d '\n')

    # Modified payload
    PAYLOAD=$(cat <<EOF
{
    "mailFrom": "no-reply@example.com",
    "mailTo": "$mailTo",
    "mailCc": "$mailCc",
    "mailSubject": "System Data Report and Alerts",
    "mailBody": "$ESCAPED_HTML_BODY",
    "attachments": [],
    "isSensitive": false
}
EOF
)

    # Perform the API call
    response=$(curl -k -s -o response_body.txt \
                   --max-time 30 --retry 3 --retry-delay 5 \
                   -X POST "$API_URL" \
                   -H "Content-Type: application/json" \
                   -d "$PAYLOAD" \
                   -w "%{http_code}")

    if [ "$response" -eq 200 ]; then
        log_and_print "Email sent successfully."
    else
        log_and_print "Failed to send email. HTTP status code: $response."
        log_and_print "Response body:"
        cat response_body.txt | while read -r line; do log_and_print "$line"; done
    fi
 else
        log_and_print "All metrics are within the acceptable range. No email sent."
    fi
}

# Main execution
rotate_log_file
log_and_print "Starting system check..."
send_system_data_and_notifications
