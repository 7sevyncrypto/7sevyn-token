# 7SEVYN Token

Community-governed BEP-20 token on Binance Smart Chain.

## Overview

7SEVYN is built around one mechanic: the Annual Tax Vote. Every year, token holders vote to set the transaction tax rate for the following 12 months. The rate can be set between 1% and a hard-capped maximum of 10%. Every participating wallet carries equal weight regardless of holdings.

## Contract

- **Contract Address:** 0x082c818a0bc956d6E7d1EBdBe89D3a24806B1484
- **Network:** Binance Smart Chain (BSC)
- **Standard:** BEP-20
- **Launch Date:** June 1, 2026
- **Source Code:** [7SEVYN.sol](https://github.com/7sevyncrypto/7sevyn-token/blob/main/7SEVYN.sol)
- **BSCScan:** https://bscscan.com/token/0x082c818a0bc956d6E7d1EBdBe89D3a24806B1484

## Tokenomics

Initial allocation at launch, June 1, 2026:

| Allocation | Percentage | Tokens | Notes |
|---|---|---|---|
| Developer Wallet | 7% | 5,390,000,000 | Locked 6 months |
| Liquidity Pool | 7% | 5,390,000,000 | Locked until June 1, 2027 |
| Community Reserve | 7% | 5,390,000,000 | Governance-directed |
| Community Vesting | 79% | 60,830,000,000 | Locked until 2031, see below |
| **Total** | **100%** | **77,000,000,000** | Fixed, no minting |

The 79% community allocation is the portion that was placed into vesting on July 28, 2026. It vests to the Community Reserve over time and is separate from the Community Reserve's initial 7%.

## Community Vesting

On July 28, 2026 the 79% community allocation was placed in a UNCX vesting contract. Total supply is unchanged at 77,000,000,000. Nothing was minted and nothing was burned.

- **Amount Locked:** 60,861,000,000 tokens
- **Locker:** UNCX Network, Vest ID 620
- **Network:** BNB Smart Chain
- **Vesting Contract:** 0x7f3f9f4ED8987B78adC448a840169A0FD5AFFAAB
- **Recipient:** Community Reserve (0x3CC7fDaed5956200d1a536eBDCccd73dA04fD88d)
- **Schedule:** 16 equal releases of 3,803,812,500 tokens
- **First Release:** July 28, 2027, following a one-year cliff
- **Last Release:** July 28, 2031
- **Cancellable:** No
- **Transferable:** No
- **Vest Page:** https://app.uncx.network/vesting-v2/flux/56-620

The wallet's balance grew from 60,830,000,000 at launch to 60,921,969,832 by July 28, 2026 through reflection rewards. Of that balance, 60,861,000,000 was locked, approximately 60,921,922 was paid to UNCX as the locker fee, and 47,910 remains in the deployer wallet.

Each released tranche is directed by community vote. The vote is conducted off-chain and results are executed on-chain by the project multisig.

### Vesting Execution Transactions

- Deployer set reflection-exempt, July 17, 2026: https://bscscan.com/tx/0xf355df47567dcc5dca3a0dea4227ffee0de68f9ad65a72dbf0d0ed2db498a129
- Exemptions batch, July 28, 2026: https://bscscan.com/tx/0xb32cef87844000c548e76e3d7a154e33dadf6687784674a37e3630d0644a0db9
- Vest created, July 28, 2026: https://bscscan.com/tx/0x344fbbec5d1ba0dfbd4f5135e916c4b43830a20bc3ff1115301405c3aeae8b18

## Tax Distribution (Default 7%)

| Allocation | Rate | Notes |
|---|---|---|
| Reflections to Holders | 3% | Auto-distributed every transaction. Adjustable via Annual Tax Vote |
| Liquidity Pool | 2% | Auto-added via SwapBack. Adjustable via Annual Tax Vote |
| Growth and Operations | 1% | Adjustable via Annual Tax Vote |
| Core Development | 1% | Fixed permanently, cannot be changed by governance |

## Annual Tax Vote

Once per year, every eligible wallet votes to set the tax rate for the following 12 months. Equal-weight model: one wallet, one vote regardless of holdings. Result executed on-chain by project multisig.

The vote itself is conducted off-chain. The token contract does not contain voting logic.

## Security

- **Audit:** Moogle Labs, April 2026. 14 findings identified, all 14 resolved. [Full report](https://github.com/7sevyncrypto/7sevyn-token/blob/main/Moogle_Labs_Audit_7SEVYN_v1.1_Final.pdf)
- **Liquidity Lock:** UNCX Network, locked until June 1, 2027
- **LP Lock Certificate:** https://app.uncx.network/lockers/manage/lockers-v2?service=edit&locker=0xc765bddb93b0d1c1a88282ba0fa6b2d00e3e0c83&pool=0xDfc1CC4b6603A1D80B34d2B389Db5B8DfE39D6b0&lock=0&index=0&wallet=0x4214d9F164358DaF690fF3dac293965696f4840C&chain=56
- **Community Vesting Lock:** UNCX Network, Vest ID 620, locked until July 28, 2031
- **Contract Ownership:** 2-of-3 multisig Governance Safe
- **Developer wallet fee exemption:** Permanently blocked at contract level

## Anti-Whale Protections

- **Maximum transaction:** 0.5% of supply (385,000,000 tokens)
- **Maximum wallet:** 1% of supply (770,000,000 tokens)
- **Developer wallet:** Locked 6 months, maximum 4% per sell, 24 hour announcement required

## Operational Wallets

| Wallet | Address |
|---|---|
| Governance Multisig | 0x2D10B1B34099D3B2B9CeCb7Fd849ee7fdD374f98 |
| Growth and Operations | 0x6Daf96Aa80d50164ED6AE3FaFfc1543AB0715979 |
| Core Development | 0xca9070A4c588d226E5a2d67fA1b88eEA09a39201 |
| Developer (Locked 6mo) | 0x7027217dd9E1aC8f586A3F3D0ecACb0E66648D73 |
| Community Reserve | 0x3CC7fDaed5956200d1a536eBDCccd73dA04fD88d |
| UNCX Vesting Contract | 0x7f3f9f4ED8987B78adC448a840169A0FD5AFFAAB |
| Deployer | 0x4214d9F164358DaF690fF3dac293965696f4840C |
| PancakeSwap Pair | 0xDfc1CC4b6603A1D80B34d2B389Db5B8DfE39D6b0 |

## Links

- **Website:** https://www.7sevyncrypto.com
- **Verified Facts:** https://www.7sevyncrypto.com/facts
- **Whitepaper:** https://7sevyncrypto.com/7SEVYN_Whitepaper_V14_1_Final.pdf
- **DEXScreener:** https://dexscreener.com/bsc/0xdfc1cc4b6603a1d80b34d2b389db5b8dfe39d6b0
- **PancakeSwap:** https://pancakeswap.finance/swap?outputCurrency=0x082c818a0bc956d6E7d1EBdBe89D3a24806B1484
