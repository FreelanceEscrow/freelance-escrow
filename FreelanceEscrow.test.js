// test/FreelanceEscrow.test.js
const { ethers }        = require("hardhat");
const { expect }        = require("chai");
const { loadFixture }   = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// ════════════════════════════════════════════════════════════
//  FIXTURE — deploys contract once, reused in every test
// ════════════════════════════════════════════════════════════
async function deployEscrowFixture() {
  const [owner, client, freelancer, arbiter, stranger] =
    await ethers.getSigners();

  const FreelanceEscrow = await ethers.getContractFactory("FreelanceEscrow");
  const escrow          = await FreelanceEscrow.deploy();
  await escrow.waitForDeployment();

  return { escrow, owner, client, freelancer, arbiter, stranger };
}

// ════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════
const ONE_ETH      = ethers.parseEther("1.0");
const HALF_ETH     = ethers.parseEther("0.5");
const DEADLINE     = 7;   // days

async function createTestJob(escrow, client, freelancer, arbiter) {
  return escrow.connect(client).createJob(
    freelancer.address,
    arbiter.address,
    "Logo Design",
    "Design a logo for my company",
    DEADLINE,
    { value: ONE_ETH }
  );
}

// ════════════════════════════════════════════════════════════
//  TEST SUITE
// ════════════════════════════════════════════════════════════
describe("FreelanceEscrow", function () {

  // ──────────────────────────────────────────────────────────
  //  1. DEPLOYMENT
  // ──────────────────────────────────────────────────────────
  describe("Deployment", function () {

    it("sets the correct owner", async function () {
      const { escrow, owner } = await loadFixture(deployEscrowFixture);
      expect(await escrow.owner()).to.equal(owner.address);
    });

    it("starts with platformFee = 0", async function () {
      const { escrow } = await loadFixture(deployEscrowFixture);
      expect(await escrow.platformFee()).to.equal(0);
    });

    it("starts with jobCount = 0", async function () {
      const { escrow } = await loadFixture(deployEscrowFixture);
      expect(await escrow.jobCount()).to.equal(0);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  2. CREATE JOB
  // ──────────────────────────────────────────────────────────
  describe("createJob()", function () {

    it("creates a job and stores correct data", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const job = await escrow.getJob(1);
      expect(job.id).to.equal(1);
      expect(job.client).to.equal(client.address);
      expect(job.freelancer).to.equal(freelancer.address);
      expect(job.arbiter).to.equal(arbiter.address);
      expect(job.payment).to.equal(ONE_ETH);
      expect(job.title).to.equal("Logo Design");
    });

    it("sets status to Funded after creation", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(1); // Funded = 1
    });

    it("increments jobCount", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      expect(await escrow.jobCount()).to.equal(1);

      await createTestJob(escrow, client, freelancer, arbiter);
      expect(await escrow.jobCount()).to.equal(2);
    });

    it("locks ETH in contract", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const contractBalance = await ethers.provider.getBalance(
        await escrow.getAddress()
      );
      expect(contractBalance).to.equal(ONE_ETH);
    });

    it("adds job to clientJobs mapping", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const clientJobList = await escrow.getClientJobs(client.address);
      expect(clientJobList.length).to.equal(1);
      expect(clientJobList[0]).to.equal(1);
    });

    it("adds job to freelancerJobs mapping", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const freelancerJobList = await escrow.getFreelancerJobs(
        freelancer.address
      );
      expect(freelancerJobList.length).to.equal(1);
      expect(freelancerJobList[0]).to.equal(1);
    });

    it("emits JobCreated and JobFunded events", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await expect(createTestJob(escrow, client, freelancer, arbiter))
        .to.emit(escrow, "JobCreated")
        .withArgs(1, client.address, ONE_ETH, "Logo Design")
        .and.to.emit(escrow, "JobFunded")
        .withArgs(1, client.address, ONE_ETH);
    });

    it("reverts if no ETH sent", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(client).createJob(
          freelancer.address,
          arbiter.address,
          "Test",
          "Desc",
          7,
          { value: 0 }
        )
      ).to.be.revertedWith("Must fund the job");
    });

    it("reverts if title is empty", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(client).createJob(
          freelancer.address,
          arbiter.address,
          "",
          "Desc",
          7,
          { value: ONE_ETH }
        )
      ).to.be.revertedWith("Title required");
    });

    it("reverts if freelancer is zero address", async function () {
      const { escrow, client, arbiter } =
        await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(client).createJob(
          ethers.ZeroAddress,
          arbiter.address,
          "Test",
          "Desc",
          7,
          { value: ONE_ETH }
        )
      ).to.be.revertedWithCustomError(escrow, "ZeroAddress");
    });

    it("reverts if client tries to hire themselves", async function () {
      const { escrow, client, arbiter } =
        await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(client).createJob(
          client.address,
          arbiter.address,
          "Test",
          "Desc",
          7,
          { value: ONE_ETH }
        )
      ).to.be.revertedWith("Cannot hire yourself");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  3. START JOB
  // ──────────────────────────────────────────────────────────
  describe("startJob()", function () {

    it("allows freelancer to start a funded job", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(2); // Started = 2
    });

    it("emits JobStarted event", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      await expect(escrow.connect(freelancer).startJob(1))
        .to.emit(escrow, "JobStarted")
        .withArgs(1, freelancer.address);
    });

    it("reverts if called by non-freelancer", async function () {
      const { escrow, client, freelancer, arbiter, stranger } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      await expect(
        escrow.connect(stranger).startJob(1)
      ).to.be.revertedWithCustomError(escrow, "NotFreelancer");
    });

    it("reverts if job is not in Funded status", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);

      await expect(
        escrow.connect(freelancer).startJob(1)
      ).to.be.revertedWithCustomError(escrow, "InvalidStatus");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  4. SUBMIT WORK
  // ──────────────────────────────────────────────────────────
  describe("submitWork()", function () {

    it("allows freelancer to submit work", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest123");

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(3); // Submitted = 3
      expect(job.workProof).to.equal("ipfs://QmTest123");
    });

    it("sets submittedAt timestamp", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest123");

      const job = await escrow.getJob(1);
      expect(job.submittedAt).to.be.greaterThan(0);
    });

    it("emits WorkSubmitted event", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);

      await expect(
        escrow.connect(freelancer).submitWork(1, "ipfs://QmTest123")
      )
        .to.emit(escrow, "WorkSubmitted")
        .withArgs(1, freelancer.address, "ipfs://QmTest123");
    });

    it("reverts if proof link is empty", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);

      await expect(
        escrow.connect(freelancer).submitWork(1, "")
      ).to.be.revertedWith("Proof required");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  5. APPROVE WORK
  // ──────────────────────────────────────────────────────────
  describe("approveWork()", function () {

    it("pays freelancer correctly with 0% fee", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");

      const balanceBefore = await ethers.provider.getBalance(
        freelancer.address
      );
      await escrow.connect(client).approveWork(1);
      const balanceAfter = await ethers.provider.getBalance(
        freelancer.address
      );

      // freelancer should receive 1 ETH (0% fee)
      expect(balanceAfter - balanceBefore).to.be.closeTo(
        ONE_ETH,
        ethers.parseEther("0.001") // allow small gas variance
      );
    });

    it("pays freelancer correctly with 2.5% fee", async function () {
      const { escrow, owner, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      // Set 2.5% platform fee
      await escrow.connect(owner).updateFee(250);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");

      const freelancerBefore = await ethers.provider.getBalance(
        freelancer.address
      );
      await escrow.connect(client).approveWork(1);
      const freelancerAfter = await ethers.provider.getBalance(
        freelancer.address
      );

      const expectedPayout = ethers.parseEther("0.975"); // 97.5%
      expect(freelancerAfter - freelancerBefore).to.be.closeTo(
        expectedPayout,
        ethers.parseEther("0.001")
      );
    });

    it("sets job status to Approved", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).approveWork(1);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(4); // Approved = 4
    });

    it("emits JobCompleted event", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");

      await expect(escrow.connect(client).approveWork(1))
        .to.emit(escrow, "JobCompleted")
        .withArgs(1, freelancer.address, ONE_ETH);
    });

    it("reverts if called by non-client", async function () {
      const { escrow, client, freelancer, arbiter, stranger } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");

      await expect(
        escrow.connect(stranger).approveWork(1)
      ).to.be.revertedWithCustomError(escrow, "NotClient");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  6. DISPUTE
  // ──────────────────────────────────────────────────────────
  describe("raiseDispute() + resolveDispute()", function () {

    it("client can raise a dispute", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).raiseDispute(1);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(5); // Dispute = 5
    });

    it("emits DisputeRaised event", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");

      await expect(escrow.connect(client).raiseDispute(1))
        .to.emit(escrow, "DisputeRaised")
        .withArgs(1, client.address);
    });

    it("arbiter can resolve in favour of freelancer", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).raiseDispute(1);

      const freelancerBefore = await ethers.provider.getBalance(
        freelancer.address
      );
      await escrow.connect(arbiter).resolveDispute(1, true); // freelancer wins
      const freelancerAfter = await ethers.provider.getBalance(
        freelancer.address
      );

      expect(freelancerAfter).to.be.greaterThan(freelancerBefore);
    });

    it("arbiter can resolve in favour of client", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).raiseDispute(1);

      const clientBefore = await ethers.provider.getBalance(client.address);
      await escrow.connect(arbiter).resolveDispute(1, false); // client wins
      const clientAfter = await ethers.provider.getBalance(client.address);

      expect(clientAfter).to.be.greaterThan(clientBefore);
    });

    it("sets job status to Resolved", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).raiseDispute(1);
      await escrow.connect(arbiter).resolveDispute(1, true);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(7); // Resolved = 7
    });

    it("reverts if non-arbiter tries to resolve", async function () {
      const { escrow, client, freelancer, arbiter, stranger } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmTest");
      await escrow.connect(client).raiseDispute(1);

      await expect(
        escrow.connect(stranger).resolveDispute(1, true)
      ).to.be.revertedWithCustomError(escrow, "NotArbiter");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  7. CANCEL JOB
  // ──────────────────────────────────────────────────────────
  describe("cancelJob()", function () {

    it("client can cancel a funded job and gets refund", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      const clientBefore = await ethers.provider.getBalance(client.address);
      await escrow.connect(client).cancelJob(1);
      const clientAfter = await ethers.provider.getBalance(client.address);

      expect(clientAfter).to.be.greaterThan(clientBefore);
    });

    it("sets status to Refunded", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(client).cancelJob(1);

      const job = await escrow.getJob(1);
      expect(job.status).to.equal(6); // Refunded = 6
    });

    it("emits JobCancelled event", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);

      await expect(escrow.connect(client).cancelJob(1))
        .to.emit(escrow, "JobCancelled")
        .withArgs(1, client.address);
    });

    it("reverts if job already started", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await escrow.connect(freelancer).startJob(1);

      await expect(
        escrow.connect(client).cancelJob(1)
      ).to.be.revertedWith("Cannot cancel at this stage");
    });
  });

  // ──────────────────────────────────────────────────────────
  //  8. PLATFORM FEE
  // ──────────────────────────────────────────────────────────
  describe("updateFee()", function () {

    it("owner can update the fee", async function () {
      const { escrow, owner } = await loadFixture(deployEscrowFixture);

      await escrow.connect(owner).updateFee(500);
      expect(await escrow.platformFee()).to.equal(500);
    });

    it("reverts if fee exceeds 1000 bps (10%)", async function () {
      const { escrow, owner } = await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(owner).updateFee(1001)
      ).to.be.revertedWith("Max 10% fee");
    });

    it("reverts if non-owner tries to update fee", async function () {
      const { escrow, stranger } = await loadFixture(deployEscrowFixture);

      await expect(
        escrow.connect(stranger).updateFee(100)
      ).to.be.revertedWith("Not Owner");
    });

    it("allows exactly 1000 bps (10%)", async function () {
      const { escrow, owner } = await loadFixture(deployEscrowFixture);

      await escrow.connect(owner).updateFee(1000);
      expect(await escrow.platformFee()).to.equal(1000);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  9. VIEW FUNCTIONS
  // ──────────────────────────────────────────────────────────
  describe("View functions", function () {

    it("getJob() returns correct job data", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      const job = await escrow.getJob(1);

      expect(job.client).to.equal(client.address);
      expect(job.freelancer).to.equal(freelancer.address);
      expect(job.title).to.equal("Logo Design");
    });

    it("getStatusString() returns correct string", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      expect(await escrow.getStatusString(1)).to.equal("Funded");

      await escrow.connect(freelancer).startJob(1);
      expect(await escrow.getStatusString(1)).to.equal("Started");
    });

    it("timeRemaining() returns positive value", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      const remaining = await escrow.timeRemaining(1);
      expect(remaining).to.be.greaterThan(0);
    });

    it("isDeadlinePassed() returns false for new job", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      expect(await escrow.isDeadlinePassed(1)).to.equal(false);
    });

    it("platformStats() returns correct totals", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      await createTestJob(escrow, client, freelancer, arbiter);
      await createTestJob(escrow, client, freelancer, arbiter);

      const [totalJobs, totalLocked] = await escrow.platformStats();
      expect(totalJobs).to.equal(2);
      expect(totalLocked).to.equal(ethers.parseEther("2.0"));
    });
  });

  // ──────────────────────────────────────────────────────────
  //  10. FULL HAPPY PATH — end to end
  // ──────────────────────────────────────────────────────────
  describe("Full happy path", function () {

    it("complete job lifecycle: create → start → submit → approve", async function () {
      const { escrow, client, freelancer, arbiter } =
        await loadFixture(deployEscrowFixture);

      // 1. Client creates job
      await escrow.connect(client).createJob(
        freelancer.address,
        arbiter.address,
        "Full Project",
        "Build a website",
        14,
        { value: ONE_ETH }
      );
      expect(await escrow.getStatusString(1)).to.equal("Funded");

      // 2. Freelancer starts
      await escrow.connect(freelancer).startJob(1);
      expect(await escrow.getStatusString(1)).to.equal("Started");

      // 3. Freelancer submits
      await escrow.connect(freelancer).submitWork(1, "ipfs://QmFinalWork");
      expect(await escrow.getStatusString(1)).to.equal("Submitted");

      // 4. Client approves
      const freelancerBefore = await ethers.provider.getBalance(
        freelancer.address
      );
      await escrow.connect(client).approveWork(1);
      const freelancerAfter = await ethers.provider.getBalance(
        freelancer.address
      );

      expect(await escrow.getStatusString(1)).to.equal("Approved");
      expect(freelancerAfter).to.be.greaterThan(freelancerBefore);

      console.log("  Full happy path completed successfully!");
    });
  });
});