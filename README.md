# 7SEVYN Token

Community-governed BEP-20 token on Binance Smart Chain.

## Overview

7SEVYN is built around one mechanic: the Annual Tax Vote. Every year, token holders vote to set the transaction tax rate for the following 12 months. The rate can be set between 1% and a hard-capped maximum of 10%. Every participating wallet carries equal weight regardless of holdings.

## Contract

- **Contract Address:** 0x082c818a0bc956d6E7d1EBdBe89D3a24806B1484
- **Network:** Binance Smart Chain (BSC)
- **Standard:** BEP-20
- **Launch Date:** June 1, 2026
- **BSCScan:** https://bscscan.com/token/0x082c818a0bc956d6E7d1EBdBe89D3a24806B1484

## Tokenomics

| Allocation | Percentage | Tokens | Notes |
|---|---|---|---|
| Developer Wallet | 7% | 5,390,000,000 | Locked 6 months |
| Liquidity Pool | 7% | 5,390,000,000 | Locked 12 months |
| Community Reserve | 7% | 5,390,000,000 | Governance-directed |
| Circulating Supply | 79% | 60,830,000,000 | Available at launch |
| **Total** | **100%** | **77,000,000,000** | Fixed, no minting |

## Tax Distribution (Default 7%)

| Allocation | Rate | Notes |
|---|---|---|
| Reflections to Holders | 3% | Auto-distributed every transaction |
| Liquidity Pool | 2% | Auto-added via SwapBack |
| Growth and Operations | 1% | Adjustable via Annual Tax Vote |
| Core Development | 1% | Fixed permanently |

## Annual Tax Vote

Once per year, every eligible wallet votes to set the tax rate for the following 12 months. Equal-weight model: one wallet, one vote regardless of holdings. Result executed on-chain by project multisig.

## Security

- **Audit:** Moogle Labs, April 2026. 14 findings identified, all 14 resolved.
- **Liquidity Lock:** UNCX Network, locked until June 1, 2027
- **LP Lock Certificate:** https://app.uncx.network/lockers/manage/lockers-v2?service=edit&locker=0xc765bddb93b0d1c1a88282ba0fa6b2d00e3e0c83&pool=0xDfc1CC4b6603A1D80B34d2B389Db5B8DfE39D6b0&lock=0&index=0&wallet=0x4214d9F164358DaF690fF3dac293965696f4840C&chain=56
- **Contract Ownership:** 2-of-3 multisig Governance Safe
- **Developer wallet fee exemption:** Permanently blocked at contract level

## Anti-Whale Protections

- Maximum transaction:
