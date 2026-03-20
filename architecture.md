# Freelance Escrow — Full Stack Architecture

> Complete workflow of how the **Frontend**, **Backend**, **Blockchain**, and **Database** connect together.

---

## 3D Architecture Overview

```
                        ╔══════════════════════════════════╗
                        ║        USER / BROWSER            ║
                        ║   (MetaMask installed)           ║
                        ╚══════════════╤═══════════════════╝
                                       │
               ┌───────────────────────┴───────────────────────┐
               │                                               │
               ▼                                               ▼
╔══════════════════════════╗                 ╔══════════════════════════╗
║     React / Next.js      ║                 ║   MetaMask + ethers.js   ║
║  ┌────────────────────┐  ║                 ║  ┌────────────────────┐  ║
║  │  Pages & Components│  ║                 ║  │   Wallet Connect   │  ║
║  │  Job List          │  ║                 ║  │   Sign Transaction │  ║
║  │  Create Job Form   │  ║                 ║  │   Send ETH         │  ║
║  │  Dashboard         │  ║                 ║  └────────────────────┘  ║
║  └────────────────────┘  ║                 ╚═══════════╤══════════════╝
╚══════════╤═══════════════╝                             │
           │                                             │ signs + sends tx
           │ REST API calls                              │
           ▼                                             ▼
╔══════════════════════════╗                 ╔══════════════════════════╗
║   Node.js / Express API  ║                 ║      Event Indexer       ║
║  ┌────────────────────┐  ║                 ║  ┌────────────────────┐  ║
║  │  POST /auth        │  ║                 ║  │ Listens to events  │  ║
║  │  GET  /jobs        │  ║                 ║  │ JobCreated         │  ║
║  │  POST /jobs        │  ║                 ║  │ WorkSubmitted      │  ║
║  │  GET  /users       │  ║                 ║  │ JobCompleted       │  ║
║  └────────────────────┘  ║                 ║  └────────┬───────────┘  ║
╚══════════╤═══════════════╝                 ╚═══════════│══════════════╝
           │                                             │ events fired
           │ calls contract                              │ (upward async)
           ▼                                             ▼
╔══════════════════════════╗                 ╔══════════════════════════╗
║    Ethereum Network      ║◄────────────────║   FreelanceEscrow.sol    ║
║  ┌────────────────────┐  ║   deployed on   ║  ┌────────────────────┐  ║
║  │  EVM execution     │  ║                 ║  │  createJob()       │  ║
║  │  Block validation  │  ║                 ║  │  startJob()        │  ║
║  │  Consensus (PoS)   │  ║                 ║  │  submitWork()      │  ║
║  │  State storage     │  ║                 ║  │  approveWork()     │  ║
║  └────────────────────┘  ║                 ║  │  raiseDispute()    │  ║
╚══════════╤═══════════════╝                 ║  │  resolveDispute()  │  ║
           │                                 ║  └────────────────────┘  ║
           │ stores off-chain data           ╚═══════════╤══════════════╝
           ▼                                             │ stores files
╔══════════════════════════╗                 ╔═══════════▼══════════════╗
║  PostgreSQL / MongoDB    ║                 ║    IPFS / Arweave        ║
║  ┌────────────────────┐  ║                 ║  ┌────────────────────┐  ║
║  │  users table       │  ║                 ║  │  Work proof files  │  ║
║  │  job_index table   │◄─╫─────────────────╫──│  NFT metadata      │  ║
║  │  notifications     │  ║  indexer writes ║  │  Contract docs     │  ║
║  │  session tokens    │  ║                 ║  │  Images / PDFs     │  ║
║  └────────────────────┘  ║                 ║  └────────────────────┘  ║
╚══════════════════════════╝                 ╚══════════════════════════╝
```

---

## Layer by Layer Explanation

### Layer 1 — User / Browser
The end user opens the web app in their browser with MetaMask installed.
They can see job listings, create jobs, and interact with their wallet.

### Layer 2 — Frontend
| Component | Tech | Purpose |
|---|---|---|
| UI Framework | React / Next.js | Pages, routing, components |
| Styling | Tailwind CSS | Design system |
| Wallet | MetaMask | Ethereum wallet in browser |
| Web3 Library | ethers.js | Talk to smart contract |
| State | Redux / Zustand | Global app state |

### Layer 3 — Backend
| Component | Tech | Purpose |
|---|---|---|
| API Server | Node.js + Express | REST endpoints |
| Authentication | JWT tokens | User sessions |
| Event Indexer | ethers.js listener | Listen to contract events |
| Validation | Joi / Zod | Input validation |

### Layer 4 — Blockchain
| Component | Purpose |
|---|---|
| Ethereum Network | Decentralized execution environment |
| Sepolia Testnet | Testing before mainnet |
| FreelanceEscrow.sol | Main smart contract |
| EVM | Runs the contract code |

### Layer 5 — Storage
| Component | Tech | Stores What |
|---|---|---|
| Off-chain DB | PostgreSQL / MongoDB | User profiles, job index, notifications |
| Decentralized Storage | IPFS / Arweave | Work files, NFT metadata, documents |

---

## Data Flow — Step by Step

### Happy Path (Job Created → Completed)

```
Step 1: Client opens app
        Browser → React UI loads dashboard
        React → Express API: GET /jobs (fetch job list)
        Express → PostgreSQL: SELECT * FROM job_index

Step 2: Client creates job
        Client fills form → clicks "Create Job"
        React → MetaMask popup: "Confirm transaction?"
        MetaMask → signs transaction with private key
        ethers.js → sends tx to Ethereum network
        Ethereum → runs FreelanceEscrow.createJob()
        Smart contract → locks ETH in escrow
        Smart contract → emits JobCreated event

Step 3: Event indexer picks up event
        Event Indexer → hears JobCreated event
        Event Indexer → Express API: POST /jobs/index
        Express → PostgreSQL: INSERT INTO job_index

Step 4: Freelancer accepts job
        Freelancer → opens app, sees job in dashboard
        Freelancer → clicks "Start Job"
        MetaMask → signs transaction
        Smart contract → FreelanceEscrow.startJob()
        Smart contract → emits JobStarted event

Step 5: Freelancer submits work
        Freelancer → uploads file to IPFS
        IPFS → returns content hash (CID)
        Freelancer → clicks "Submit Work" with IPFS link
        Smart contract → FreelanceEscrow.submitWork(ipfsHash)
        Smart contract → emits WorkSubmitted event

Step 6: Client approves work
        Client → reviews work at IPFS link
        Client → clicks "Approve"
        Smart contract → FreelanceEscrow.approveWork()
        Smart contract → transfers 97.5% ETH to freelancer
        Smart contract → transfers 2.5% fee to platform
        Smart contract → emits JobCompleted event

Step 7: Frontend updates
        Event Indexer → hears JobCompleted
        Updates database → job marked complete
        React UI → re-fetches data → shows "Completed" ✅
```

---

## Tech Stack Summary

```
┌─────────────────────────────────────────────────────────┐
│                    TECH STACK                           │
├──────────────┬──────────────────────────────────────────┤
│ Frontend     │ React, Next.js, Tailwind CSS             │
│ Wallet       │ MetaMask, ethers.js v6                   │
│ Backend      │ Node.js, Express, JWT                    │
│ Smart Contract│ Solidity 0.8.20, OpenZeppelin           │
│ Dev Tools    │ Hardhat, Chai, dotenv                    │
│ Blockchain   │ Ethereum (Sepolia testnet)               │
│ Database     │ PostgreSQL + Prisma ORM                  │
│ File Storage │ IPFS (via Pinata or web3.storage)        │
│ Indexing     │ ethers.js event listener / The Graph     │
│ Deployment   │ Vercel (frontend), Railway (backend)     │
└──────────────┴──────────────────────────────────────────┘
```

---

## Folder Structure

```
freelance-escrow/
│
├── contracts/                    ← Solidity smart contracts
│   └── FreelanceEscrow.sol
│
├── scripts/                      ← Hardhat deploy scripts
│   └── deploy.js
│
├── test/                         ← Contract unit tests
│   └── FreelanceEscrow.test.js
│
├── frontend/                     ← React / Next.js app
│   ├── pages/
│   │   ├── index.js              ← Job listing page
│   │   ├── create.js             ← Create job page
│   │   └── jobs/[id].js          ← Job detail page
│   ├── components/
│   │   ├── JobCard.jsx
│   │   ├── ConnectWallet.jsx
│   │   └── CreateJobForm.jsx
│   └── utils/
│       ├── contract.js           ← ethers.js contract setup
│       └── ipfs.js               ← IPFS upload helper
│
├── backend/                      ← Node.js API server
│   ├── routes/
│   │   ├── jobs.js               ← Job endpoints
│   │   └── users.js              ← User endpoints
│   ├── models/
│   │   ├── Job.js                ← Job DB model
│   │   └── User.js               ← User DB model
│   ├── indexer/
│   │   └── eventListener.js      ← Listens to contract events
│   └── server.js                 ← Express app entry point
│
├── hardhat.config.js
├── package.json
├── .env
└── ARCHITECTURE.md               ← this file ✅
```

---

## Environment Variables

```bash
# .env (NEVER push to GitHub!)

# Blockchain
PRIVATE_KEY=your_wallet_private_key
SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/your_key
ETHERSCAN_KEY=your_etherscan_api_key
CONTRACT_ADDRESS=deployed_contract_address

# Backend
DATABASE_URL=postgresql://user:pass@localhost:5432/escrow
JWT_SECRET=your_super_secret_jwt_key
PORT=5000

# IPFS
PINATA_API_KEY=your_pinata_key
PINATA_SECRET=your_pinata_secret

# Frontend
NEXT_PUBLIC_CONTRACT_ADDRESS=deployed_contract_address
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_CHAIN_ID=11155111
```

---

## Key Code Connections

### 1. Frontend → Smart Contract (ethers.js)

```javascript
// frontend/utils/contract.js
import { ethers } from "ethers";
import ABI from "../../artifacts/contracts/FreelanceEscrow.sol/FreelanceEscrow.json";

export const getContract = async () => {
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer   = await provider.getSigner();
  return new ethers.Contract(
    process.env.NEXT_PUBLIC_CONTRACT_ADDRESS,
    ABI.abi,
    signer
  );
};

// Create a job from React component
export const createJob = async (freelancer, title, days, ethAmount) => {
  const contract = await getContract();
  const tx = await contract.createJob(
    freelancer,
    arbiterAddress,
    title,
    "Job description",
    days,
    { value: ethers.parseEther(ethAmount) }
  );
  await tx.wait();
  return tx;
};
```

### 2. Backend → Database (Prisma ORM)

```javascript
// backend/models/Job.js (Prisma schema)
model Job {
  id           Int      @id @default(autoincrement())
  jobId        Int      @unique   // on-chain job ID
  client       String             // wallet address
  freelancer   String             // wallet address
  title        String
  status       String
  payment      String             // ETH amount as string
  txHash       String             // blockchain tx hash
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
```

### 3. Event Indexer (ethers.js listener)

```javascript
// backend/indexer/eventListener.js
import { ethers } from "ethers";
import { db } from "../db.js";

const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC);
const contract = new ethers.Contract(
  process.env.CONTRACT_ADDRESS,
  ABI,
  provider
);

// Listen to JobCreated event from smart contract
contract.on("JobCreated", async (jobId, client, payment, title) => {
  console.log(`New job created: #${jobId} by ${client}`);

  // Save to database
  await db.job.create({
    data: {
      jobId:     Number(jobId),
      client:    client,
      title:     title,
      status:    "Funded",
      payment:   ethers.formatEther(payment),
    }
  });
});

// Listen to JobCompleted event
contract.on("JobCompleted", async (jobId, freelancer, payment) => {
  await db.job.update({
    where: { jobId: Number(jobId) },
    data:  { status: "Completed" }
  });
});

console.log("Event indexer running...");
```

### 4. IPFS Upload (work proof)

```javascript
// frontend/utils/ipfs.js
import axios from "axios";

export const uploadToIPFS = async (file) => {
  const formData = new FormData();
  formData.append("file", file);

  const res = await axios.post(
    "https://api.pinata.cloud/pinning/pinFileToIPFS",
    formData,
    {
      headers: {
        pinata_api_key:        process.env.PINATA_API_KEY,
        pinata_secret_api_key: process.env.PINATA_SECRET,
      }
    }
  );

  // Returns IPFS hash (CID)
  return `ipfs://${res.data.IpfsHash}`;
  // e.g. ipfs://QmXyz123...
  // This is what gets stored in the smart contract
};
```

---

## Security Notes

```
✅ Smart contract security:
   - Re-entrancy guard (nonReentrant modifier)
   - CEI pattern (Checks → Effects → Interactions)
   - Role-based access (onlyClient, onlyFreelancer)
   - Custom errors (cheaper gas than require strings)

✅ Backend security:
   - JWT authentication on all routes
   - Input validation with Joi/Zod
   - Rate limiting
   - CORS configured

✅ Never store:
   - Private keys in code
   - Secrets in .env committed to GitHub
   - Sensitive user data on-chain (use IPFS hashes)
```

---

## Deployment

```
Smart Contract  → Sepolia testnet → then Ethereum mainnet
Frontend        → Vercel (free tier)
Backend API     → Railway or Render (free tier)
Database        → Railway PostgreSQL or Supabase
IPFS            → Pinata (free 1GB)
```


<img width="1292" height="1178" alt="image" src="https://github.com/user-attachments/assets/38e90554-5130-472d-968d-b50cffedda76" />

---

*Built with Solidity 0.8.20 · ethers.js v6 · React · Node.js · PostgreSQL · IPFS*
