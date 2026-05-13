curl -sSL https://aspire.dev/install.sh | bash
source /root/.bashrc

export ASPIRE_DASHBOARD_URL=http://0.0.0.0:17000
export ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL=http://0.0.0.0:17001
export DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true
export ASPIRE_ALLOW_UNSECURED_TRANSPORT=true