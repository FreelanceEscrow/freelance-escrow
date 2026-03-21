// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
contract FreelanceEscrow {

    // ── Enum ──────────────────────────────────────────────────
    enum JobStatus {
        Created,
        Funded,
        Started,
        Submitted,
        Approved,    // ✅ FIX 10: was "Completed" in code, enum says Approved
        Dispute,     // ✅ FIX 9:  was "Disputed" in code, enum says Dispute
        Refunded,    // ✅ FIX 11: was "Cancelled" in code, enum says Refunded
        Resolved
    }

    // ── Struct ────────────────────────────────────────────────
    struct Job {
        uint256   id;
        address   client;
        address   freelancer;
        address   arbiter;
        uint256   payment;
        uint256   deadline;
        JobStatus status;
        string    title;
        string    description;
        uint256   createdAt;
        uint256   submittedAt;
        string    workProof;
    }

    // ── Mappings ──────────────────────────────────────────────
    mapping(uint256 => Job) public jobs;          // ✅ FIX 1: uint256 not address
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public freelancerJobs;

    uint256 public jobCount;
    uint256 public platformFee = 0;
    address public owner;

    // ── Events ────────────────────────────────────────────────
    event JobCreated(
        uint indexed jobId,
        address indexed client,
        uint256 payment,
        string title
    );
    event JobFunded(
        uint indexed jobId,
        address indexed client,
        uint256 amount
    );
    event JobStarted(
        uint indexed jobId,
        address indexed freelancer
    );
    event WorkSubmitted(
        uint indexed jobId,
        address indexed freelancer,
        string proof
    );
    event JobCompleted(
        uint indexed jobId,
        address indexed freelancer,
        uint256 amount
    );
    event DisputeRaised(
        uint indexed jobId,
        address indexed raisedBy
    );
    event DisputeResolved(
        uint indexed jobId,
        address indexed resolvedBy,
        uint256 amount
    );
    event JobCancelled(
        uint indexed jobId,
        address indexed cancelledBy
    );

    // ── Custom Errors ─────────────────────────────────────────
    error ZeroAddress();
    error NotClient(address caller);
    error NotFreelancer(address caller);
    error NotArbiter(address caller);
    error InvalidStatus(JobStatus current, JobStatus required);
    error DeadlinePassed(uint256 deadline, uint256 current);
    error InsufficientPayment(uint256 sent, uint256 required);

    // ── Constructor ───────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ── Modifiers ─────────────────────────────────────────────
    modifier onlyClient(uint256 jobId) {      // ✅ FIX 2: jobID → jobId
        if (msg.sender != jobs[jobId].client) {
            revert NotClient(msg.sender);
        }
        _;
    }

    modifier onlyFreelancer(uint256 jobId) {
        if (msg.sender != jobs[jobId].freelancer) {
            revert NotFreelancer(msg.sender);
        }
        _;
    }

    modifier onlyArbiter(uint256 jobId) {
        if (msg.sender != jobs[jobId].arbiter) {
            revert NotArbiter(msg.sender);
        }
        _;
    }

    modifier inStatus(uint256 jobId, JobStatus required) {
        if (jobs[jobId].status != required) {
            revert InvalidStatus(jobs[jobId].status, required);
        }
        _;
    }

    modifier beforeDeadline(uint256 jobId) {
        if (block.timestamp > jobs[jobId].deadline) {
            revert DeadlinePassed(jobs[jobId].deadline, block.timestamp);
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;                                    // ✅ FIX 3: added missing _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) {             // ✅ FIX 4: address[0] → address(0)
            revert ZeroAddress();
        }
        _;
    }

    // ── Create Job ────────────────────────────────────────────
    function createJob(
        address freelancer,
        address arbiter,
        string memory title,
        string memory description,
        uint256 deadlineDays              // ✅ FIX 5: renamed deadline → deadlineDays
    )
        external
        payable
        validAddress(freelancer)
        validAddress(arbiter)
        returns (uint256 jobId)
    {
        require(msg.value > 0,                   "Must fund the job");
        require(bytes(title).length > 0,         "Title required");
        require(deadlineDays > 0,                "Invalid deadline");
        require(freelancer != msg.sender,        "Cannot hire yourself");

        jobId = ++jobCount;

        jobs[jobId] = Job({
            id:          jobId,
            client:      msg.sender,
            freelancer:  freelancer,
            arbiter:     arbiter,
            payment:     msg.value,
            deadline:    block.timestamp + (deadlineDays * 1 days),
            status:      JobStatus.Funded,
            title:       title,
            description: description,
            createdAt:   block.timestamp,
            submittedAt: 0,
            workProof:   ""
        });

        clientJobs[msg.sender].push(jobId);    // ✅ FIX 6: JobId → jobId
        freelancerJobs[freelancer].push(jobId); // ✅ FIX 6: JobId → jobId

        emit JobCreated(jobId, msg.sender, msg.value, title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // ── Start Job ─────────────────────────────────────────────
    function startJob(uint256 jobId)
        external
        onlyFreelancer(jobId)
        inStatus(jobId, JobStatus.Funded)
        beforeDeadline(jobId)
    {
        jobs[jobId].status = JobStatus.Started;
        emit JobStarted(jobId, msg.sender);
    }

    // ── Submit Work ───────────────────────────────────────────
    function submitWork(uint256 jobId, string memory proofLink)
        external
        onlyFreelancer(jobId)
        inStatus(jobId, JobStatus.Started)
        beforeDeadline(jobId)
    {
        require(bytes(proofLink).length > 0, "Proof required");

        jobs[jobId].status      = JobStatus.Submitted;
        jobs[jobId].submittedAt = block.timestamp;
        jobs[jobId].workProof   = proofLink;

        emit WorkSubmitted(jobId, msg.sender, proofLink);
    }

    // ── Approve Work ──────────────────────────────────────────
    function approveWork(uint256 jobId)
        external
        onlyClient(jobId)
        inStatus(jobId, JobStatus.Submitted)
    {
        Job storage job = jobs[jobId];
        job.status = JobStatus.Approved;       // ✅ FIX 10: Completed → Approved

        uint256 fee    = (job.payment * platformFee) / 10_000;
        uint256 payout = job.payment - fee;

        (bool ok1, ) = job.freelancer.call{value: payout}("");
        require(ok1, "Freelancer payment failed");

        (bool ok2, ) = owner.call{value: fee}("");  // ✅ FIX 7: payout → fee
        require(ok2, "Fee payment failed");

        emit JobCompleted(jobId, job.freelancer, payout);
    }

    // ── Raise Dispute ─────────────────────────────────────────
    function raiseDispute(uint256 jobId)    // ✅ FIX 8: raisedDispute → raiseDispute
        external
        onlyClient(jobId)
        inStatus(jobId, JobStatus.Submitted)
    {
        jobs[jobId].status = JobStatus.Dispute;  // ✅ FIX 9: Disputed → Dispute
        emit DisputeRaised(jobId, msg.sender);
    }

    // ── Resolve Dispute ───────────────────────────────────────
    function resolveDispute(uint256 jobId, bool freelancerWins)
        external
        onlyArbiter(jobId)
        inStatus(jobId, JobStatus.Dispute)       // ✅ FIX 9: Disputed → Dispute
    {
        Job storage job = jobs[jobId];
        job.status = JobStatus.Resolved;

        address winner = freelancerWins ? job.freelancer : job.client;

        uint256 fee    = (job.payment * platformFee) / 10_000;
        uint256 payout = job.payment - fee;

        (bool ok1, ) = winner.call{value: payout}("");
        require(ok1, "Winner payment failed");

        (bool ok2, ) = job.arbiter.call{value: fee / 2}("");
        require(ok2, "Arbiter payment failed");

        emit DisputeResolved(jobId, winner, payout);
    }

    // ── Cancel Job ────────────────────────────────────────────
    function cancelJob(uint256 jobId)
        external
        onlyClient(jobId)                        // ✅ FIX 12: onlyClinet → onlyClient
    {
        Job storage job = jobs[jobId];           // ✅ FIX 13: capital Job → lowercase job

        require(
            job.status == JobStatus.Funded ||
            job.status == JobStatus.Created,
            "Cannot cancel at this stage"
        );

        job.status = JobStatus.Refunded;         // ✅ FIX 11: Cancelled → Refunded

        (bool ok, ) = job.client.call{value: job.payment}("");
        require(ok, "Refund failed");

        emit JobCancelled(jobId, msg.sender);
    }

    // ── Claim Refund After Deadline ───────────────────────────
    function claimRefundAfterDeadline(uint256 jobId)
        external
        onlyClient(jobId)
    {
        Job storage job = jobs[jobId];           // ✅ FIX 13: capital Job → lowercase job

        require(block.timestamp > job.deadline,  "Deadline not passed yet");
        require(
            job.status == JobStatus.Funded ||
            job.status == JobStatus.Started,
            "Cannot refund at this stage"
        );

        job.status = JobStatus.Refunded;         // ✅ FIX 11: Cancelled → Refunded

        (bool ok, ) = job.client.call{value: job.payment}("");
        require(ok, "Refund failed");

        emit JobCancelled(jobId, msg.sender);
    }

    // ── View Functions ────────────────────────────────────────

    function getJob(uint256 jobId)
        external view returns (Job memory)
    {
        return jobs[jobId];
    }

    function getClientJobs(address client)
        external view returns (uint256[] memory)
    {
        return clientJobs[client];               // ✅ FIX 14: [jobId] → [client]
    }

    function getFreelancerJobs(address freelancer)  // ✅ FIX 15: funtion → function
        external view returns (uint256[] memory)
    {
        return freelancerJobs[freelancer];       // ✅ FIX 16: [jobId] → [freelancer]
    }

    function getStatusString(uint256 jobId)
        external view returns (string memory)
    {
        JobStatus s = jobs[jobId].status;        // ✅ FIX 17: jobsId → jobId

        if (s == JobStatus.Created)   return "Created";
        if (s == JobStatus.Funded)    return "Funded";
        if (s == JobStatus.Started)   return "Started";
        if (s == JobStatus.Submitted) return "Submitted";
        if (s == JobStatus.Approved)  return "Approved";  // ✅ FIX 10
        if (s == JobStatus.Dispute)   return "Disputed";  // ✅ FIX 9
        if (s == JobStatus.Refunded)  return "Refunded";  // ✅ FIX 11
        if (s == JobStatus.Resolved)  return "Resolved";
        return "Unknown";
    }

    function isDeadlinePassed(uint256 jobId)
        external view returns (bool)
    {
        return block.timestamp > jobs[jobId].deadline;
    }

    function timeRemaining(uint256 jobId)
        external view returns (uint256)
    {
        if (block.timestamp >= jobs[jobId].deadline) return 0;
        return jobs[jobId].deadline - block.timestamp;
    }

    function platformStats()                     // ✅ FIX 18: platfromStats → platformStats
        external view
        returns (uint256 totalJobs, uint256 totalLocked)
    {
        totalJobs   = jobCount;
        totalLocked = address(this).balance;
    }

    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Max 10% fee");
        platformFee = newFee;
    }
}