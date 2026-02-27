// Copyright 2026 Nick Brassel (@tzarc)
// SPDX-License-Identifier: GPL-2.0-or-later

#include <stddef.h>
#include <stdlib.h>

#undef malloc
void *rpl_malloc(size_t n);

#if __has_include("config.h")
#include "config.h"
#endif
