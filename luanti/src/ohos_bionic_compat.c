// SPDX-License-Identifier: LGPL-2.1-or-later
// Minimal shims so Android NDK static libs can link on OHOS/musl.
// Replace by rebuilding deps for x86_64-linux-ohos when possible.

#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/select.h>
#include <wchar.h>

#include <hilog/log.h>

int *__errno(void)
{
	return &errno;
}

size_t wcslcpy(wchar_t *dst, const wchar_t *src, size_t size)
{
	const wchar_t *s = src;
	size_t n = size;

	if (n == 0 || !dst)
		return s ? wcslen(s) : 0;

	if (!s) {
		dst[0] = L'\0';
		return 0;
	}

	while (--n != 0) {
		if ((*dst++ = *s++) == L'\0')
			return s - src - 1;
	}

	*dst = L'\0';
	return s - src + wcslen(s);
}

size_t wcslcat(wchar_t *dst, const wchar_t *src, size_t size)
{
	wchar_t *d = dst;
	const wchar_t *s = src;
	size_t n = size;
	size_t dlen;

	while (n-- != 0 && *d != L'\0')
		d++;
	dlen = d - dst;
	n = size - dlen;

	if (n == 0)
		return dlen + wcslen(s);

	while (--n != 0) {
		if ((*d++ = *s++) == L'\0')
			break;
	}
	*d = L'\0';
	return dlen + (s - src - 1) + wcslen(s);
}

static int ohos_log_priority(int android_prio)
{
	switch (android_prio) {
	case 2: return LOG_DEBUG;
	case 3: return LOG_DEBUG;
	case 4: return LOG_INFO;
	case 5: return LOG_WARN;
	case 6: return LOG_ERROR;
	default: return LOG_INFO;
	}
}

int __android_log_print(int prio, const char *tag, const char *fmt, ...)
{
	va_list ap;
	char buf[1024];

	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);

	OH_LOG_Print(LOG_APP, (LogLevel)ohos_log_priority(prio), 0, tag ? tag : "Luanti", "%{public}s", buf);
	return 0;
}

int __android_log_write(int prio, const char *tag, const char *text)
{
	OH_LOG_Print(LOG_APP, (LogLevel)ohos_log_priority(prio), 0, tag ? tag : "Luanti", "%{public}s",
		text ? text : "");
	return 0;
}

/* Bionic stdio anchor used by Android-built static libraries (opaque on musl). */
char __sF[3][256];

/* Android NDK libcurl uses fortified FD_* macros; musl/OHOS has no __FD_*_chk. */
void __FD_SET_chk(int fd, fd_set *set, size_t set_size)
{
	(void)set_size;
	if (fd < 0 || !set)
		return;
	FD_SET(fd, set);
}

void __FD_CLR_chk(int fd, fd_set *set, size_t set_size)
{
	(void)set_size;
	if (fd < 0 || !set)
		return;
	FD_CLR(fd, set);
}

int __FD_ISSET_chk(int fd, fd_set *set, size_t set_size)
{
	(void)set_size;
	if (fd < 0 || !set)
		return 0;
	return FD_ISSET(fd, set) ? 1 : 0;
}
