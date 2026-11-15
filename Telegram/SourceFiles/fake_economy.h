/*
Phantom economy add-on for Telegram Desktop (local client-side display only).

Overrides the displayed Stars / TON balances and lets gift sends resolve as
"paid" without any RPC leaving the client. Purely visual: nothing is synced and
the server never sees a request. Enabled at runtime through environment vars:

    TD_FAKE_ECONOMY=1 TD_FAKE_STARS=999999 TD_FAKE_TON=13370 ./Telegram

Without TD_FAKE_ECONOMY the whole thing is a no-op and behaviour is stock.

Two balance modes are supported:

    TD_FAKE_INFINITE=1          # never decreases, always shows TD_FAKE_STARS
    TD_FAKE_STARS=inf           # same, alias
    TD_FAKE_STARS=500           # spends from 500, ticks down per send

The spending mode counts phantom sends locally, so the number falls to 0
instead of staying fixed. Gifts still resolve as paid, nothing is sent.
*/
#pragma once

#include "core/credits_amount.h"

#include <cstdint>
#include <cstdlib>
#include <algorithm>

namespace FakeEconomy {

inline bool enabled() {
	static const bool on = (std::getenv("TD_FAKE_ECONOMY") != nullptr);
	return on;
}

// Infinite currency mode: the balance never goes down, no matter how many
// phantom gifts are sent. Enabled by TD_FAKE_INFINITE=1 or TD_FAKE_STARS=inf.
inline bool infinite() {
	static const bool on = [] {
		if (const auto v = std::getenv("TD_FAKE_INFINITE")) {
			return (v[0] != '\0' && v[0] != '0');
		}
		if (const auto v = std::getenv("TD_FAKE_STARS")) {
			const auto value = QByteArray(v).toLower();
			return (value == "inf") || (value == "infinite");
		}
		return false;
	}();
	return on;
}

inline int64 stars() {
	const auto v = std::getenv("TD_FAKE_STARS");
	if (!v) {
		return 999999;
	}
	const auto value = QByteArray(v).toLower();
	if (value == "inf" || value == "infinite") {
		return 999999;
	}
	return std::strtoll(v, nullptr, 10);
}

inline int64 tonWhole() {
	const auto v = std::getenv("TD_FAKE_TON");
	return v ? std::strtoll(v, nullptr, 10) : int64(13370);
}

// Price shown for transferring a phantom unique gift. Real Telegram asks the
// server for it; locally we use a believable fixed fee (0 = free transfer).
inline int transferStars() {
	const auto v = std::getenv("TD_FAKE_TRANSFER_STARS");
	return v ? int(std::strtol(v, nullptr, 10)) : 25;
}

// fake amount already "spent" on phantom gifts this session, so the balance
// ticks down believably instead of looking infinite
inline int64 &spentStars() {
	static int64 value = 0;
	return value;
}

inline void spend(int64 amount) {
	if (enabled() && amount > 0) {
		spentStars() += amount;
	}
}

inline CreditsAmount balance(CreditsAmount real) {
	if (!enabled()) {
		return real;
	}
	if (real.ton()) {
		return CreditsAmount(tonWhole(), 0, CreditsType::Ton);
	}
	if (infinite()) {
		return CreditsAmount(stars());
	}
	return CreditsAmount(std::max<int64>(0, stars() - spentStars()));
}

inline CreditsAmount tonBalance(CreditsAmount real) {
	return enabled()
		? CreditsAmount(tonWhole(), 0, CreditsType::Ton)
		: real;
}

} // namespace FakeEconomy
