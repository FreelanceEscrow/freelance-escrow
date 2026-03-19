<div align="center">

<!-- Animated Header Banner -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0f172a,50:6366f1,100:0ea5e9&height=200&section=header&text=FreelanceEscrow&fontSize=60&fontColor=ffffff&fontAlignY=38&desc=Decentralized%20Freelancer%20Platform%20on%20Web3&descAlignY=58&descSize=18&animation=fadeIn" width="100%"/>

<!-- Badges Row 1 -->
<p>
  <img src="https://img.shields.io/badge/Status-Active-22c55e?style=for-the-badge&labelColor=0f172a" />
  <img src="https://img.shields.io/badge/License-MIT-6366f1?style=for-the-badge&labelColor=0f172a" />
  <img src="https://img.shields.io/badge/Web3-Powered-0ea5e9?style=for-the-badge&logo=ethereum&logoColor=white&labelColor=0f172a" />
  <img src="https://img.shields.io/badge/Blockchain-Solidity-f59e0b?style=for-the-badge&logo=ethereum&logoColor=white&labelColor=0f172a" />
</p>

<!-- Badges Row 2 -->
<p>
  <img src="https://img.shields.io/github/stars/FreelanceEscrow/freelance-escrow?style=for-the-badge&logo=github&logoColor=white&color=f59e0b&labelColor=0f172a" />
  <img src="https://img.shields.io/github/forks/FreelanceEscrow/freelance-escrow?style=for-the-badge&logo=github&logoColor=white&color=6366f1&labelColor=0f172a" />
  <img src="https://img.shields.io/github/issues/FreelanceEscrow/freelance-escrow?style=for-the-badge&logo=github&logoColor=white&color=ef4444&labelColor=0f172a" />
  <img src="https://img.shields.io/github/last-commit/FreelanceEscrow/freelance-escrow?style=for-the-badge&logo=github&logoColor=white&color=0ea5e9&labelColor=0f172a" />
</p>

<br/>

> **"Removing intermediaries. Building the future of freelancing on blockchain."**

</div>

---

## 🌌 What is FreelanceEscrow?

**FreelanceEscrow** by **FreelanceEscrow** is a fully decentralized freelancer marketplace that leverages smart contracts to eliminate middlemen, enable borderless work, and protect both clients and freelancers through trustless escrow payments.

No agencies. No fees. No trust required — just code.

---

## ✨ Core Features

<div align="center">

| 🔐 Smart Escrow | ⭐ On-Chain Reputation |
|:---:|:---:|
| Payments locked in smart contracts until milestone completion. Funds are released automatically — no disputes, no delays. | Every review and rating is written immutably to the blockchain. Your reputation is yours forever — no platform can erase it. |

| 👛 Wallet Authentication | 📁 Project Lifecycle |
|:---:|:---:|
| Log in with MetaMask, WalletConnect, or any Web3 wallet. No email, no password — full decentralized identity. | Create projects, set milestones, track deliverables, and manage payments — all from one dashboard. |

</div>

---

## ⚙️ Tech Stack

<div align="center">

<!-- Frontend -->
<img src="https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB" />
<img src="https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white" />
<img src="https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white" />
<img src="https://img.shields.io/badge/TailwindCSS-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white" />

<br/>

<!-- Backend -->
<img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" />
<img src="https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white" />

<br/>

<!-- Blockchain -->
<img src="https://img.shields.io/badge/Solidity-363636?style=for-the-badge&logo=solidity&logoColor=white" />
<img src="https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=ethereum&logoColor=white" />
<img src="https://img.shields.io/badge/Hardhat-FFF100?style=for-the-badge&logo=ethereum&logoColor=black" />
<img src="https://img.shields.io/badge/Web3.js-F16822?style=for-the-badge&logo=web3dotjs&logoColor=white" />

<br/>

<!-- Storage / Tools -->
<img src="https://img.shields.io/badge/IPFS-65C2CB?style=for-the-badge&logo=ipfs&logoColor=white" />
<img src="https://img.shields.io/badge/MetaMask-E2761B?style=for-the-badge&logo=metamask&logoColor=white" />
<img src="https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white" />

</div>

---

## 🗺️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      User Interface                      │
│              Next.js  ·  React  ·  Tailwind              │
└───────────────────────┬─────────────────────────────────┘
                        │
          ┌─────────────▼─────────────┐
          │       Web3 Layer           │
          │  MetaMask · WalletConnect  │
          └─────────────┬─────────────┘
                        │
     ┌──────────────────▼──────────────────┐
     │         Smart Contracts (Solidity)   │
     │  ┌──────────────┐ ┌──────────────┐  │
     │  │   Escrow.sol │ │Reputation.sol│  │
     │  └──────────────┘ └──────────────┘  │
     └──────────────────┬──────────────────┘
                        │
          ┌─────────────▼─────────────┐
          │     Ethereum Network       │
          │    + IPFS File Storage     │
          └────────────────────────────┘
```

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/FreelanceEscrow/freelance-escrow.git
cd freelance-escrow

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local

# Compile & deploy smart contracts
npx hardhat compile
npx hardhat run scripts/deploy.js --network localhost

# Start the development server
npm run dev
```

> 💡 Make sure you have **MetaMask** installed and connected to your local Hardhat network.

---

## 📂 Project Structure

```
freelance-escrow/
├── 📁 contracts/          # Solidity smart contracts
│   ├── Escrow.sol
│   └── Reputation.sol
├── 📁 frontend/           # Next.js application
│   ├── components/
│   ├── pages/
│   └── hooks/             # Web3 custom hooks
├── 📁 backend/            # Node.js API server
│   ├── routes/
│   └── controllers/
├── 📁 scripts/            # Hardhat deploy scripts
└── 📁 test/               # Contract unit tests
```

---

## 🔐 How Escrow Works

```
Client Posts Job
      │
      ▼
Freelancer Applies & Gets Hired
      │
      ▼
Client Deposits Funds → Smart Contract Locks Payment
      │
      ▼
Freelancer Completes Milestone
      │
      ▼
Client Approves Delivery
      │
      ▼
Smart Contract Releases Funds to Freelancer ✅
```

> In case of dispute, a decentralized arbitration mechanism handles resolution on-chain.

---

## 🛣️ Roadmap

- [x] 🔐 Smart Escrow Contract
- [x] 👛 Wallet Authentication
- [x] 📁 Project Listing & Management
- [x] ⭐ On-Chain Reputation System
- [ ] 🤝 Decentralized Dispute Resolution
- [ ] 💱 Multi-token Payment Support (USDC, DAI)
- [ ] 📱 Mobile App (React Native)
- [ ] 🌐 Multi-chain Support (Polygon, Arbitrum)
- [ ] 🤖 AI-powered Freelancer Matching

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a **Pull Request**

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for our code of conduct.

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">

**Built with ❤️ by [FreelanceEscrow](https://github.com/FreelanceEscrow)**

<br/>

<a href="https://github.com/FreelanceEscrow/freelance-escrow">
  <img src="https://img.shields.io/badge/⭐_Star_this_repo-f59e0b?style=for-the-badge&labelColor=0f172a" />
</a>
&nbsp;
<a href="https://github.com/FreelanceEscrow/freelance-escrow/fork">
  <img src="https://img.shields.io/badge/🍴_Fork_it-6366f1?style=for-the-badge&labelColor=0f172a" />
</a>
&nbsp;
<a href="https://github.com/FreelanceEscrow/freelance-escrow/issues">
  <img src="https://img.shields.io/badge/🐛_Report_Bug-ef4444?style=for-the-badge&labelColor=0f172a" />
</a>

<br/><br/>

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0ea5e9,50:6366f1,100:0f172a&height=100&section=footer" width="100%"/>

</div>
