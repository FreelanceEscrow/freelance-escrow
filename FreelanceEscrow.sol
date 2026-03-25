// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FreelanceEscrow {

    // ── Enum ──────────────────────────────────────────────────
    enum JobStatus {
        Created,
        Funded,
        Started,
        Submitted,
        Approved,
        Dispute,
        Refunded,
        Resolved
    }

    enum Category {
        Design,
        Development,
        Writing,
        Marketing,
        Video,
        Music,
        Other
    }

    // ── Structs ───────────────────────────────────────────────
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
        Category  category;
        string[]  tags;
    }

    struct Rating {
        uint8   score;
        string  comment;
        address ratedBy;
        uint256 givenAt;
    }

    struct Arbiter {
        address arbiter1;
        address arbiter2;
        address arbiter3;
        bool    voted1;
        bool    voted2;
        bool    voted3;
        uint8   freelancerVoted;
        uint8   clientVoted;
        bool    resolved;
    }

    // ── Mappings ──────────────────────────────────────────────
    mapping(uint256 => Job)       public jobs;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public freelancerJobs;

    uint256 public jobCount;
    uint256 public platformFee = 0;
    address public owner;
    bool    public paused;

    mapping(address => Rating[])  public freelancerRatings;
    mapping(address => Rating[])  public clientRatings;
    mapping(uint256 => bool)      public jobRatedByClient;
    mapping(uint256 => bool)      public jobRatedByFreelancer;
    mapping(uint256 => uint256[]) public jobsByCategory;
    mapping(uint256 => Arbiter)   public arbiterVotes;

    // ── Events ────────────────────────────────────────────────
    event JobCreated(uint indexed jobId, address indexed client, uint256 payment, string title);
    event JobFunded(uint indexed jobId, address indexed client, uint256 amount);
    event JobStarted(uint indexed jobId, address indexed freelancer);
    event WorkSubmitted(uint indexed jobId, address indexed freelancer, string proof);
    event JobCompleted(uint indexed jobId, address indexed freelancer, uint256 amount);
    event DisputeRaised(uint indexed jobId, address indexed raisedBy);
    event DisputeResolved(uint indexed jobId, address indexed resolvedBy, uint256 amount);
    event JobCancelled(uint indexed jobId, address indexed cancelledBy);
    event ContractPaused(address indexed by, uint256 timestamp);
    event ContractNotPaused(address indexed by, uint256 timestamp);
    event FreelancerRated(uint256 jobId, address indexed freelancer, uint8 score);
    event ClientRated(uint256 jobId, address indexed client, uint8 score);
    event TipSent(uint256 jobId, address indexed client, address indexed freelancer, uint256 amount);
    event DeadlineExtended(uint256 jobId, uint256 newDeadline, uint256 oldDeadline);
    event ArbiterVoted(uint256 jobId, address indexed arbiter, bool votedForFreelancer);

    // ── Custom Errors ─────────────────────────────────────────
    error ZeroAddress();
    error NotClient(address caller);
    error NotFreelancer(address caller);
    error NotArbiter(address caller);
    error InvalidStatus(JobStatus current, JobStatus required);
    error DeadlinePassed(uint256 deadline, uint256 current);
    error InsufficientPayment(uint256 sent, uint256 required);
    error AlreadyRated();
    error InvalidScore(uint8 score);
    error ZeroTip();
    error JobNotCompleted();
    error DeadlineTooShort();
    error NotAnArbiter(address caller);
    error AlreadyVoted(address arbiter);
    error DisputeAlreadyResolved();

    // ── Constructor ───────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ── Modifiers ─────────────────────────────────────────────
    modifier onlyClient(uint256 jobId) {
        if (msg.sender != jobs[jobId].client) revert NotClient(msg.sender);
        _;
    }
    modifier onlyFreelancer(uint256 jobId) {
        if (msg.sender != jobs[jobId].freelancer) revert NotFreelancer(msg.sender);
        _;
    }
    modifier onlyArbiter(uint256 jobId) {
        if (msg.sender != jobs[jobId].arbiter) revert NotArbiter(msg.sender);
        _;
    }
    modifier inStatus(uint256 jobId, JobStatus required) {
        if (jobs[jobId].status != required) revert InvalidStatus(jobs[jobId].status, required);
        _;
    }
    modifier beforeDeadline(uint256 jobId) {
        if (block.timestamp > jobs[jobId].deadline)
            revert DeadlinePassed(jobs[jobId].deadline, block.timestamp);
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }
    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "Contract is Paused");
        _;
    }

    // ── Create Job ────────────────────────────────────────────
    function createJob(
        address freelancer,
        address arbiter1,
        address arbiter2,
        address arbiter3,
        string memory title,
        string memory description,
        uint256 deadlineDays,
        Category category,
        string[] memory tags
    )
        external
        payable
        validAddress(freelancer)
        validAddress(arbiter1)
        validAddress(arbiter2)
        validAddress(arbiter3)
        returns (uint256 jobId)
    {
        require(msg.value > 0,                 "Must fund the job");
        require(bytes(title).length > 0,       "Title required");
        require(deadlineDays > 0,              "Invalid deadline");
        require(freelancer != msg.sender,      "Cannot hire yourself");
        require(
            arbiter1 != arbiter2 && arbiter2 != arbiter3 && arbiter1 != arbiter3,
            "Arbiters must be different"
        );

        jobId = ++jobCount;

        jobs[jobId] = Job({
            id:          jobId,
            client:      msg.sender,
            freelancer:  freelancer,
            arbiter:     arbiter1,
            payment:     msg.value,
            deadline:    block.timestamp + (deadlineDays * 1 days),
            status:      JobStatus.Funded,
            title:       title,
            description: description,
            createdAt:   block.timestamp,
            submittedAt: 0,
            workProof:   "",
            category:    category,
            tags:        new string[](0)
        });

        for (uint256 i = 0; i < tags.length; i++) {
            jobs[jobId].tags.push(tags[i]);
        }

        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(category)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter1;
        arbiterVotes[jobId].arbiter2 = arbiter2;
        arbiterVotes[jobId].arbiter3 = arbiter3;

        emit JobCreated(jobId, msg.sender, msg.value, title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // ── Start Job ─────────────────────────────────────────────
    function startJob(uint256 jobId)
        external
        whenNotPaused
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
        whenNotPaused
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
        whenNotPaused
        onlyClient(jobId)
        inStatus(jobId, JobStatus.Submitted)
    {
        Job storage job = jobs[jobId];
        job.status = JobStatus.Approved;

        uint256 fee    = (job.payment * platformFee) / 10_000;
        uint256 payout = job.payment - fee;

        (bool ok1, ) = job.freelancer.call{value: payout}("");
        require(ok1, "Freelancer payment failed");

        if (fee > 0) {
            (bool ok2, ) = owner.call{value: fee}("");
            require(ok2, "Fee payment failed");
        }

        emit JobCompleted(jobId, job.freelancer, payout);
    }

    // ── Raise Dispute ─────────────────────────────────────────
    function raiseDispute(uint256 jobId)
        external
        onlyClient(jobId)
        inStatus(jobId, JobStatus.Submitted)
    {
        jobs[jobId].status = JobStatus.Dispute;
        emit DisputeRaised(jobId, msg.sender);
    }

    // ── Resolve Dispute (single arbiter) ──────────────────────
    function resolveDispute(uint256 jobId, bool freelancerWins)
        external
        onlyArbiter(jobId)
        inStatus(jobId, JobStatus.Dispute)
    {
        Job storage job = jobs[jobId];
        job.status = JobStatus.Resolved;

        address winner = freelancerWins ? job.freelancer : job.client;

        uint256 fee    = (job.payment * platformFee) / 10_000;
        uint256 payout = job.payment - fee;

        (bool ok1, ) = winner.call{value: payout}("");
        require(ok1, "Winner payment failed");

        if (fee > 0) {
            (bool ok2, ) = job.arbiter.call{value: fee / 2}("");
            require(ok2, "Arbiter payment failed");
        }

        emit DisputeResolved(jobId, winner, payout);
    }

    // ── Cancel Job ────────────────────────────────────────────
    function cancelJob(uint256 jobId) external onlyClient(jobId) {
        Job storage job = jobs[jobId];

        require(
            job.status == JobStatus.Funded ||
            job.status == JobStatus.Created,
            "Cannot cancel at this stage"
        );

        job.status = JobStatus.Refunded;

        (bool ok, ) = job.client.call{value: job.payment}("");
        require(ok, "Refund failed");

        emit JobCancelled(jobId, msg.sender);
    }

    // ── Claim Refund After Deadline ───────────────────────────
    function claimRefundAfterDeadline(uint256 jobId) external onlyClient(jobId) {
        Job storage job = jobs[jobId];

        require(block.timestamp > job.deadline, "Deadline not passed yet");
        require(
            job.status == JobStatus.Funded ||
            job.status == JobStatus.Started,
            "Cannot refund at this stage"
        );

        job.status = JobStatus.Refunded;

        (bool ok, ) = job.client.call{value: job.payment}("");
        require(ok, "Refund failed");

        emit JobCancelled(jobId, msg.sender);
    }

    // ── Emergency Pause ───────────────────────────────────────
    function pause() external onlyOwner {
        require(!paused, "Already Paused");
        paused = true;
        emit ContractPaused(msg.sender, block.timestamp);
    }

    function unpause() external onlyOwner {
        require(paused, "Not Paused");
        paused = false;
        emit ContractNotPaused(msg.sender, block.timestamp);
    }

    // ── Rating System ─────────────────────────────────────────
    function rateFreelancer(uint256 jobId, uint8 score, string memory comment)
        external
        onlyClient(jobId)
    {
        require(jobs[jobId].status == JobStatus.Approved, "Job not completed yet");
        if (jobRatedByClient[jobId]) revert AlreadyRated();
        if (score < 1 || score > 5)  revert InvalidScore(score);

        jobRatedByClient[jobId] = true;

        freelancerRatings[jobs[jobId].freelancer].push(Rating({
            score:   score,
            comment: comment,
            ratedBy: msg.sender,
            givenAt: block.timestamp
        }));

        emit FreelancerRated(jobId, jobs[jobId].freelancer, score);
    }

    function rateClient(uint256 jobId, uint8 score, string memory comment)
        external
        onlyFreelancer(jobId)
    {
        require(jobs[jobId].status == JobStatus.Approved, "Job not completed yet");
        if (jobRatedByFreelancer[jobId]) revert AlreadyRated();
        if (score < 1 || score > 5)      revert InvalidScore(score);

        jobRatedByFreelancer[jobId] = true;

        clientRatings[jobs[jobId].client].push(Rating({
            score:   score,
            comment: comment,
            ratedBy: msg.sender,
            givenAt: block.timestamp
        }));

        emit ClientRated(jobId, jobs[jobId].client, score);
    }

    function getFreelancerAverageRating(address freelancer)
        external view
        returns (uint256 average, uint256 totalRatings)
    {
        Rating[] memory ratings = freelancerRatings[freelancer];
        totalRatings = ratings.length;
        if (totalRatings == 0) return (0, 0);

        uint256 total = 0;
        for (uint256 i = 0; i < ratings.length; i++) {
            total += ratings[i].score;
        }
        average = (total * 10) / totalRatings;
    }

    function getClientAverageRating(address client)
        external view
        returns (uint256 average, uint256 totalRatings)
    {
        Rating[] memory ratings = clientRatings[client];
        totalRatings = ratings.length;
        if (totalRatings == 0) return (0, 0);

        uint256 total = 0;
        for (uint256 i = 0; i < ratings.length; i++) {
            total += ratings[i].score;
        }
        average = (total * 10) / totalRatings;
    }

    function getFreelancerRatings(address freelancer) external view returns (Rating[] memory) {
        return freelancerRatings[freelancer];
    }

    function getClientRatings(address client) external view returns (Rating[] memory) {
        return clientRatings[client];
    }

    // ── Tip / Bonus Payment ───────────────────────────────────
    function sendTip(uint256 jobId) external payable onlyClient(jobId) {
        if (jobs[jobId].status != JobStatus.Approved) revert JobNotCompleted();
        if (msg.value == 0) revert ZeroTip();

        (bool ok, ) = jobs[jobId].freelancer.call{value: msg.value}("");
        require(ok, "Tip transfer failed");

        emit TipSent(jobId, msg.sender, jobs[jobId].freelancer, msg.value);
    }

    // ── Category Helpers ──────────────────────────────────────
    function getJobsByCategory(Category category) external view returns (uint256[] memory) {
        return jobsByCategory[uint256(category)];
    }

    function getCategoryString(uint256 jobId) external view returns (string memory) {
        Category c = jobs[jobId].category;
        if (c == Category.Design)      return "Design";
        if (c == Category.Development) return "Development";
        if (c == Category.Marketing)   return "Marketing";
        if (c == Category.Music)       return "Music";
        if (c == Category.Video)       return "Video";
        if (c == Category.Writing)     return "Writing";
        return "Other";
    }

    // ── Job Tags ──────────────────────────────────────────────
    function getJobTags(uint256 jobId) external view returns (string[] memory) {
        return jobs[jobId].tags;
    }

    function getJobTagCount(uint256 jobId) external view returns (uint256) {
        return jobs[jobId].tags.length;
    }

    // ── Extend Deadline ───────────────────────────────────────
    function extendDeadline(uint256 jobId, uint256 extraDays) external onlyClient(jobId) {
        require(
            jobs[jobId].status == JobStatus.Started ||
            jobs[jobId].status == JobStatus.Funded,
            "Cannot extend at this stage"
        );

        if (extraDays == 0) revert DeadlineTooShort();

        uint256 oldDeadline = jobs[jobId].deadline;
        uint256 newDeadline = oldDeadline + (extraDays * 1 days);

        require(newDeadline > block.timestamp, "New deadline must be in future");

        jobs[jobId].deadline = newDeadline;

        emit DeadlineExtended(jobId, newDeadline, oldDeadline);
    }

    // ── Multi-Arbiter Voting ───────────────────────────────────
    function castArbiterVote(uint256 jobId, bool voteForFreelancer)
        external
        inStatus(jobId, JobStatus.Dispute)
    {
        Arbiter storage av = arbiterVotes[jobId];

        bool isArbiter1 = msg.sender == av.arbiter1;
        bool isArbiter2 = msg.sender == av.arbiter2;
        bool isArbiter3 = msg.sender == av.arbiter3;

        if (!isArbiter1 && !isArbiter2 && !isArbiter3) revert NotAnArbiter(msg.sender);
        if (av.resolved) revert DisputeAlreadyResolved();

        if (isArbiter1) {
            if (av.voted1) revert AlreadyVoted(msg.sender);
            av.voted1 = true;
        } else if (isArbiter2) {
            if (av.voted2) revert AlreadyVoted(msg.sender);
            av.voted2 = true;
        } else {
            if (av.voted3) revert AlreadyVoted(msg.sender);
            av.voted3 = true;
        }

        if (voteForFreelancer) av.freelancerVoted++;
        else av.clientVoted++;

        emit ArbiterVoted(jobId, msg.sender, voteForFreelancer);

        uint256 totalVotes = av.freelancerVoted + av.clientVoted;
        if (totalVotes >= 2) {
            _resolveByVotes(jobId);
        }
    }

    function _resolveByVotes(uint256 jobId) internal {
        Arbiter storage av = arbiterVotes[jobId];

        if (av.resolved) return;

        bool freelancerWins = av.freelancerVoted > av.clientVoted;
        av.resolved = true;

        jobs[jobId].status = JobStatus.Resolved;
        Job storage job = jobs[jobId];

        address winner = freelancerWins ? job.freelancer : job.client;

        uint256 fee    = (job.payment * platformFee) / 10_000;
        uint256 payout = job.payment - fee;

        (bool ok, ) = winner.call{value: payout}("");
        require(ok, "Winner payment failed");

        if (fee > 0) {
            uint256 share = fee / 3;
            (bool ok1, ) = av.arbiter1.call{value: share}("");
            require(ok1, "Arbiter1 payment failed");
            (bool ok2, ) = av.arbiter2.call{value: share}("");
            require(ok2, "Arbiter2 payment failed");
            (bool ok3, ) = av.arbiter3.call{value: share}("");
            require(ok3, "Arbiter3 payment failed");
        }

        emit DisputeResolved(jobId, winner, payout);
    }

    function getArbiterVoteStatus(uint256 jobId)
        external view
        returns (
            uint8   freelancerVotes,
            uint8   clientVotes,
            bool    resolved,
            address arbiter1,
            address arbiter2,
            address arbiter3
        )
    {
        Arbiter storage av = arbiterVotes[jobId];
        return (
            av.freelancerVoted,
            av.clientVoted,
            av.resolved,
            av.arbiter1,
            av.arbiter2,
            av.arbiter3
        );
    }

    // ── View Functions ────────────────────────────────────────
    function getJob(uint256 jobId) external view returns (Job memory) {
        return jobs[jobId];
    }

    function getClientJobs(address client) external view returns (uint256[] memory) {
        return clientJobs[client];
    }

    function getFreelancerJobs(address freelancer) external view returns (uint256[] memory) {
        return freelancerJobs[freelancer];
    }

    function getStatusString(uint256 jobId) external view returns (string memory) {
        JobStatus s = jobs[jobId].status;
        if (s == JobStatus.Created)   return "Created";
        if (s == JobStatus.Funded)    return "Funded";
        if (s == JobStatus.Started)   return "Started";
        if (s == JobStatus.Submitted) return "Submitted";
        if (s == JobStatus.Approved)  return "Approved";
        if (s == JobStatus.Dispute)   return "Disputed";
        if (s == JobStatus.Refunded)  return "Refunded";
        if (s == JobStatus.Resolved)  return "Resolved";
        return "Unknown";
    }

    function isDeadlinePassed(uint256 jobId) external view returns (bool) {
        return block.timestamp > jobs[jobId].deadline;
    }

    function timeRemaining(uint256 jobId) external view returns (uint256) {
        if (block.timestamp >= jobs[jobId].deadline) return 0;
        return jobs[jobId].deadline - block.timestamp;
    }

    function platformStats()
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

    function transferOwnership(address newOwner)
        external
        onlyOwner
        validAddress(newOwner)
    {
        owner = newOwner;
    }
}
