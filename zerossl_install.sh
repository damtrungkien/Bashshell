#!/bin/bash
# Auto SSL Installation with IP Validation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_warning() {
    echo -e "${BLUE}⚠ $1${NC}"
}

# Lấy Shared IP của cPanel account
get_cpanel_ip() {
    # Thử nhiều cách để lấy IP
    local cpanel_ip=""

    # Cách 1: Dùng UAPI
    cpanel_ip=$(uapi --output=json Variables get_user_information | grep -oP '"ip":"\K[^"]+')

    # Cách 2: Từ file datastore
    if [ -z "$cpanel_ip" ]; then
        if [ -f ~/.cpanel/datastore/main_domain_ip ]; then
            cpanel_ip=$(cat ~/.cpanel/datastore/main_domain_ip)
        fi
    fi

    # Cách 3: Từ cpanel config
    if [ -z "$cpanel_ip" ]; then
        cpanel_ip=$(grep "^IPADDR=" ~/.cpanel/cpanel.config 2>/dev/null | cut -d'=' -f2)
    fi

    echo "$cpanel_ip"
}

# Lấy IP mà domain đang trỏ đến
get_domain_ip() {
    local domain=$1
    local domain_ip=""

    # Thử nhiều tools
    # Cách 1: Dùng dig
    if command -v dig &> /dev/null; then
        domain_ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n1)
    fi

    # Cách 2: Dùng host
    if [ -z "$domain_ip" ] && command -v host &> /dev/null; then
        domain_ip=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)
    fi

    # Cách 3: Dùng nslookup
    if [ -z "$domain_ip" ] && command -v nslookup &> /dev/null; then
        domain_ip=$(nslookup "$domain" 2>/dev/null | grep "Address:" | tail -n1 | awk '{print $2}')
    fi

    # Cách 4: Dùng getent (fallback)
    if [ -z "$domain_ip" ] && command -v getent &> /dev/null; then
        domain_ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1)
    fi

    echo "$domain_ip"
}

# Kiểm tra IP có hợp lệ không
is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Kiểm tra domain trỏ đúng IP chưa
check_domain_ip() {
    local domain=$1
    local cpanel_ip=$2

    print_info "Đang kiểm tra DNS của $domain..."

    local domain_ip=$(get_domain_ip "$domain")

    if [ -z "$domain_ip" ]; then
        print_error "Không thể resolve domain $domain"
        print_warning "Domain có thể chưa có bản ghi DNS hoặc DNS chưa propagate"
        return 1
    fi

    if ! is_valid_ip "$domain_ip"; then
        print_error "IP không hợp lệ: $domain_ip"
        return 1
    fi

    print_info "Domain đang trỏ về IP: $domain_ip"
    print_info "cPanel Shared IP: $cpanel_ip"

    if [ "$domain_ip" == "$cpanel_ip" ]; then
        print_success "Domain đã trỏ đúng IP!"
        return 0
    else
        print_error "Domain CHƯA trỏ đúng IP!"
        print_warning "Domain trỏ về: $domain_ip"
        print_warning "Cần trỏ về: $cpanel_ip"
        return 1
    fi
}

# Lấy document root tự động
get_document_root() {
    local domain=$1
    local docroot=$(uapi --output=json DomainInfo single_domain_data domain=$domain 2>/dev/null | grep -oP '"documentroot":"\K[^"]+')

    if [ -z "$docroot" ]; then
        print_error "Không tìm thấy document root cho domain: $domain"
        print_info "Domain này có thể chưa được add vào cPanel"
        return 1
    fi

    echo "$docroot"
    return 0
}

# Kiểm tra xem là main domain, addon hay subdomain
detect_domain_type() {
    local domain=$1
    local main_domain=$(uapi --output=json DomainInfo single_domain_data domain=$domain 2>/dev/null | grep -oP '"main_domain":"\K[^"]+')

    # Đếm số dấu chấm
    local dot_count=$(echo "$domain" | tr -cd '.' | wc -c)

    # Nếu có 2 dấu chấm trở lên thì là subdomain (vd: demo.dotrungquan.info)
    if [ $dot_count -ge 2 ]; then
        echo "subdomain"
        return
    fi

    # Nếu domain trùng với main_domain thì là main domain
    if [ "$domain" == "$main_domain" ]; then
        echo "main"
        return
    fi

    # Còn lại là addon domain
    echo "addon"
}

# Kiểm tra bản ghi www có tồn tại không
check_www_record() {
    local domain=$1
    local cpanel_ip=$2

    print_info "Đang kiểm tra bản ghi www.$domain..."

    local www_ip=$(get_domain_ip "www.$domain")

    if [ -z "$www_ip" ]; then
        print_info "Không tìm thấy bản ghi www.$domain"
        return 1
    fi

    if ! is_valid_ip "$www_ip"; then
        print_info "Bản ghi www không hợp lệ"
        return 1
    fi

    print_info "www.$domain trỏ về IP: $www_ip"

    if [ "$www_ip" == "$cpanel_ip" ]; then
        print_success "Bản ghi www.$domain đã trỏ đúng IP"
        return 0
    else
        print_warning "Bản ghi www.$domain trỏ về IP khác: $www_ip"
        print_warning "Sẽ không cài SSL cho www.$domain"
        return 1
    fi
}

# Cài đặt SSL tự động
install_ssl_auto() {
    local domain=$1
    local skip_ip_check=$2

    echo "=================================="
    print_info "Bắt đầu cài đặt SSL cho: $domain"
    echo "=================================="

    # Lấy cPanel IP
    local cpanel_ip=$(get_cpanel_ip)

    if [ -z "$cpanel_ip" ]; then
        print_error "Không thể lấy Shared IP của cPanel"
        print_warning "Tiếp tục cài đặt mà không kiểm tra IP..."
    else
        print_success "cPanel Shared IP: $cpanel_ip"

        # Kiểm tra IP nếu không bỏ qua
        if [ "$skip_ip_check" != "skip" ]; then
            echo ""
            if ! check_domain_ip "$domain" "$cpanel_ip"; then
                echo ""
                print_error "Domain chưa trỏ đúng IP!"
                echo ""
                read -p "Bạn có muốn tiếp tục cài đặt không? (y/n): " continue_install

                if [ "$continue_install" != "y" ] && [ "$continue_install" != "Y" ]; then
                    print_info "Hủy cài đặt. Vui lòng trỏ domain về IP: $cpanel_ip"
                    return 1
                fi
                print_warning "Tiếp tục cài đặt dù domain chưa trỏ đúng..."
            fi
        fi
    fi

    echo ""

    # Lấy document root
    docroot=$(get_document_root "$domain")
    if [ $? -ne 0 ]; then
        print_error "Không thể tiếp tục. Vui lòng kiểm tra domain đã được add vào cPanel chưa."
        return 1
    fi

    print_success "Document root: $docroot"

    # Detect domain type
    domain_type=$(detect_domain_type "$domain")
    print_info "Loại domain: $domain_type"

    # Cài đặt acme.sh nếu chưa có
    if [ ! -d ~/.acme.sh ]; then
        echo ""
        print_info "Đang cài đặt acme.sh..."
        wget -O - https://get.acme.sh | sh -s email=ssl@azdigi.info
        if [ $? -eq 0 ]; then
            print_success "Cài đặt acme.sh thành công"
        else
            print_error "Cài đặt acme.sh thất bại"
            return 1
        fi
    fi

    # Xác định domains cần cài SSL
    local ssl_domains="-d $domain"
    local deploy_domains="--domain $domain"

    # Nếu là subdomain thì chỉ cài domain đó thôi
    if [ "$domain_type" == "subdomain" ]; then
        print_info "Subdomain detected - chỉ cài SSL cho $domain"
    else
        # Nếu là main domain hoặc addon domain thì kiểm tra www
        echo ""
        if [ -z "$cpanel_ip" ] || [ "$skip_ip_check" == "skip" ]; then
            # Không có IP hoặc skip check thì dùng DNS resolution thông thường
            if host "www.$domain" >/dev/null 2>&1; then
                ssl_domains="$ssl_domains -d www.$domain"
                deploy_domains="$deploy_domains --domain www.$domain"
                print_success "Sẽ cài SSL cho cả $domain và www.$domain"
            else
                print_info "Chỉ cài SSL cho $domain (không có bản ghi www)"
            fi
        else
            # Có IP thì check kỹ
            if check_www_record "$domain" "$cpanel_ip"; then
                ssl_domains="$ssl_domains -d www.$domain"
                deploy_domains="$deploy_domains --domain www.$domain"
                print_success "Sẽ cài SSL cho cả $domain và www.$domain"
            else
                print_info "Chỉ cài SSL cho $domain"
            fi
        fi
    fi

    echo ""
    print_info "Đang issue certificate..."

    # Issue certificate
    ~/.acme.sh/acme.sh --issue --webroot "$docroot" \
        $ssl_domains \
        --keylength 2048 --force

    if [ $? -ne 0 ]; then
        print_error "Issue certificate thất bại"
        print_warning "Có thể do:"
        echo "  - Domain chưa trỏ đúng IP"
        echo "  - Port 80 bị chặn"
        echo "  - Webroot không đúng"
        return 1
    fi

    print_success "Issue certificate thành công"
    echo ""
    print_info "Đang deploy certificate vào cPanel..."

    # Deploy certificate
    ~/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi \
        $deploy_domains

    if [ $? -eq 0 ]; then
        echo ""
        echo "=================================="
        print_success "CÀI ĐẶT SSL THÀNH CÔNG!"
        echo "=================================="
        print_success "Domain: $domain"
        if [[ "$ssl_domains" == *"www"* ]]; then
            print_success "Bao gồm: www.$domain"
        fi
        echo "=================================="
    else
        echo ""
        print_error "Deploy certificate thất bại"
        print_info "Certificate đã được issue nhưng chưa deploy vào cPanel"
        print_info "Bạn có thể thử deploy thủ công hoặc kiểm tra lại cPanel API token"
    fi
}

# Main script
echo "=================================="
echo "   AUTO SSL INSTALLER - cPanel"
echo "   với IP Validation"
echo "=================================="
echo ""

# Nhập domain
read -p "Nhập domain cần cài SSL: " input_domain

# Loại bỏ khoảng trắng
input_domain=$(echo "$input_domain" | xargs)

# Kiểm tra input rỗng
if [ -z "$input_domain" ]; then
    print_error "Domain không được để trống!"
    exit 1
fi

# Loại bỏ www. nếu user nhập vào
if [[ "$input_domain" == www.* ]]; then
    input_domain="${input_domain#www.}"
    print_info "Đã tự động loại bỏ www. - domain: $input_domain"
fi

echo ""
read -p "Bỏ qua kiểm tra IP? (y/n, mặc định: n): " skip_check

skip_param=""
if [ "$skip_check" == "y" ] || [ "$skip_check" == "Y" ]; then
    skip_param="skip"
    print_warning "Sẽ bỏ qua kiểm tra IP"
fi

echo ""

# Chạy cài đặt
install_ssl_auto "$input_domain" "$skip_param"
