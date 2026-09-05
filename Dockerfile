FROM n8nio/n8n:latest

# فقط برای کپی فایل و تغییر دسترسی، موقتاً به root سوئیچ می‌کنیم
USER root
COPY start.sh /docker-entrypoint.d/99-custom-env-parser.sh
RUN chmod +x /docker-entrypoint.d/99-custom-env-parser.sh

# بازگشت فوری به کاربر غیر-root برای امنیت و سازگاری با n8n
USER node

EXPOSE 5678
# ENTRYPOINT را دستکاری نمی‌کنیم تا اسکریپت‌های رسمی n8n به درستی اجرا شوند