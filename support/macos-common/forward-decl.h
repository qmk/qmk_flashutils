// Copyright 2024-2026 Nick Brassel (@tzarc)
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#ifndef __BLOCKS__
// dispatch_block_t is only defined when blocks are enabled during build... which aren't. Fake it with an opaque pointer.
typedef void* dispatch_block_t;
#endif // __BLOCKS__
