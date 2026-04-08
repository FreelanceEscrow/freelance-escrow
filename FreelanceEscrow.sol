// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20{
    function transfer(address to, uint256 amount) external returns(bool);
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
    function balanceOf(address account) external view returns(uint256);
    function allowance(address owner, address spender) external view returns(uint256);
}

interface AutomationCompatibleInterface{
    function checkUpKeep(bytes calldata checkData) external returns(bool upkeepNeeded, bytes memory performData);
    function performUpKeep(bytes calldata perfromData) external; 
}

contract FreelanceEscrow is AutomationCompatibleInterface{

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

    enum MilestoneStatus{
        Pending,
        Submitted,
        Approved,
        Disputed
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
        address paymentToken;
        uint256 tokenAmount;
        bool isTokenPayment;
    }

    struct Milestone{
        uint256 id;
        string title;
        string description;
        uint256 payment;
        MilestoneStatus status;
        string workProof;
        uint256 submittedAt;
        uint256 approvedAt;
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

    struct Profile{
        string name;
        string bio;
        string portfolioLink;
        string skills;
        uint256 hourlyRate;
        bool available;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct JobTemplate{
        uint256 id;
        string title;
        string description;
        Category category;
        uint256 defaultDeadlineDays;
        uint256 defaultBudget;
        address owner;
        bool isActive;
        uint256 createdAt;
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
    mapping(uint256 => Milestone[]) public jobMilestones;
    mapping(uint256 => bool) public isMilestoneJob;
    mapping(uint256 => uint256) public milestoneCount;
    mapping(address => Profile) public profiles;
    mapping(address => bool) public hasProfile;
    uint256[] public allJobIds;
    mapping(uint8 => uint256[]) public jobsByStatus;
    uint256[] public autoRefundEligible;
    mapping(uint256 => bool) public addedToAutoRefund;
    mapping(address=> uint256) public completedJobCount;
    mapping(address => uint256) public disputesWon;
    mapping(address => uint256) public disputesLost;
    mapping(address => uint256) public totalTipsReceived;
    mapping(uint256 => JobTemplate) public templates;
    mapping(address => uint256[]) public myTemplates;
    uint256 public templateCount;

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
    event MilestoneSubmitted(uint256 jobId, uint256 indexed milestoneId, address indexed freelancer, string workProof);
    event MilestoneApproved(uint256 indexed jobId, uint256 indexed milestoneId, address indexed freelancer, uint256 payment);
    event MilestoneDisputed(uint256 indexed jobId, uint256 indexed milestoneId, address indexed client);
    event TokenJobCreated(uint256 indexed jobId, address indexed client, address indexed token, uint256 tokenAmount);
    event TokenPaymentReleased(uint256 indexed jobId, address indexed freelancer, address indexed token, uint256 payment);
    event ProfileCreated(address indexed user, string name);
    event ProfileUpdated(address indexed user, uint256 timestamp);
    event AutoRefundExecuted(uint256 indexed jobId, address indexed client, uint256 amount);
    event ReputationUpdated(address indexed user, uint256 newScore);
    event TemplateCreated(uint256 indexed templateId, address indexed client, string title);
    event TemplateDeleted(uint256 indexed templateId, address indexed client);
    event JobCreatedFromTemplate(uint256 indexed jobId, uint256 indexed templateId);

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
    error NotMilestoneJob();
    error InvalidMilestoneId(uint256 jobId);
    error MilestoneAlreadyApproved(uint256 jobId);
    error MilestoneNotSubmitted(uint256 jobId);
    error TotalMilestonePaymentMismatch(uint256 total, uint256 jobPayment);
    error TokenTransferFailed();
    error NotTokenJob();
    error InsufficientAllowance(uint256 allowance, uint256 required);
    error ProfileNotFound(address user);
    error ProfileAlreadyExists(address user);
    error TemplateNotFound(uint256 id);
    error NotTemplateOwner(address client);
    error TemplateInactive(uint256 id);

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

    // LEGACY COMPAT — CREATE JOB (single arbiter + default category/tags)
    function createJob(
        address freelancer,
        address arbiter,
        string memory title,
        string memory description,
        uint256 deadlineDays
    )
        external
        payable
        whenNotPaused
        validAddress(freelancer)
        validAddress(arbiter)
        returns (uint256 jobId)
    {
        require(msg.value > 0,            "Must fund the job");
        require(bytes(title).length > 0,  "Title required");
        require(deadlineDays > 0,         "Invalid deadline");
        require(freelancer != msg.sender, "Cannot hire yourself");

        jobId = ++jobCount;

        jobs[jobId] = Job({
            id: jobId,
            client: msg.sender,
            freelancer: freelancer,
            arbiter: arbiter,
            payment: msg.value,
            deadline: block.timestamp + (deadlineDays * 1 days),
            status: JobStatus.Funded,
            title: title,
            description: description,
            createdAt: block.timestamp,
            submittedAt: 0,
            workProof: "",
            category: Category.Other,
            tags: new string[](0),
            paymentToken: address(0),
            tokenAmount: 0,
            isTokenPayment: false
        });

        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(Category.Other)].push(jobId);
        allJobIds.push(jobId);
        jobsByStatus[uint8(JobStatus.Funded)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter;
        arbiterVotes[jobId].arbiter2 = arbiter;
        arbiterVotes[jobId].arbiter3 = arbiter;

        _addToAutoRefund(jobId);

        emit JobCreated(jobId, msg.sender, msg.value, title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // CORE — CREATE JOB (ETH payment)
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
        whenNotPaused
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
            tags:        new string[](0),
            paymentToken: address(0),
            tokenAmount: 0,
            isTokenPayment: false
        });

        for (uint256 i = 0; i < tags.length; i++) {
            jobs[jobId].tags.push(tags[i]);
        }

        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(category)].push(jobId);

        allJobIds.push(jobId);
        jobsByStatus[uint8(JobStatus.Funded)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter1;
        arbiterVotes[jobId].arbiter2 = arbiter2;
        arbiterVotes[jobId].arbiter3 = arbiter3;

        _addToAutoRefund(jobId);

        emit JobCreated(jobId, msg.sender, msg.value, title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // CREATE JOB WITH ERC-20 TOKEN PAYMENT

    function createJobWithToken(
        address freelancer,
        address arbiter1,
        address arbiter2,
        address arbiter3,
        string memory title,
        string memory description,
        uint256 deadlineDays,
        Category category,
        string[] memory tags,
        address tokenAddress,
        uint256 tokenAmount
    )
    external
    payable 
    whenNotPaused
    validAddress(freelancer)
    validAddress(arbiter1)
    validAddress(arbiter2)
    validAddress(arbiter3)
    validAddress(tokenAddress)
    returns(uint256 jobId)
    {
        require(bytes(title).length > 0, "Title must be Required");
        require(deadlineDays > 0, "Deadline must be greater than zero");
        require(freelancer != msg.sender, "Cannot hire yourself");
        require(tokenAmount > 0, "Amount must be greater than zero");
        require(arbiter1!=arbiter2 && arbiter2 != arbiter3 && arbiter1 != arbiter3, "Arbiter must be different");

        IERC20 token = IERC20(tokenAddress);
        uint256 allowed = token.allowance(msg.sender, address(this));
        if(allowed < tokenAmount){
            revert InsufficientAllowance(allowed, tokenAmount);
        }

        bool pulled = token.transferFrom(msg.sender, address(this), tokenAmount);
        if(!pulled) revert TokenTransferFailed();

        jobId = ++jobCount;
        jobs[jobId] = Job({
            id: jobId,
            client: msg.sender,
            freelancer: freelancer,
            arbiter: arbiter1,
            payment: 0,
            deadline: block.timestamp + (deadlineDays * 1 days),
            status: JobStatus.Funded,
            title: title,
            description: description,
            createdAt: block.timestamp,
            submittedAt: 0,
            workProof: "",
            category: category,
            tags: new string[](0),
            paymentToken: tokenAddress,
            tokenAmount: tokenAmount,
            isTokenPayment: true
        });

        for(uint256 i = 0; i < tags.length; i++){
            jobs[jobId].tags.push(tags[i]);
        }
        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(category)].push(jobId);
        allJobIds.push(jobId);
        jobsByStatus[uint8(JobStatus.Funded)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter1;
        arbiterVotes[jobId].arbiter2 = arbiter2;
        arbiterVotes[jobId].arbiter3 = arbiter3;

        _addToAutoRefund(jobId);

        emit TokenJobCreated(jobId, msg.sender, tokenAddress, tokenAmount);
        emit JobCreated(jobId, msg.sender, tokenAmount, title);
    }

    // CREATE JOB WITH MILESTONES

    function createJobWithMilestone(
        address freelancer,
        address arbiter1,
        address arbiter2,
        address arbiter3,
        string memory title,
        string memory description,
        uint256 deadlineDays,
        Category category,
        string[] memory milestoneTitles,
        string[] memory milestoneDescriptions,
        uint256[] memory milestonePayments
    ) 
    external 
    payable
    whenNotPaused
    validAddress(freelancer)
    validAddress(arbiter1)
    validAddress(arbiter2)
    validAddress(arbiter3)
    returns(uint256 jobId)
    {
        require(msg.value > 0, "Must fund the Job");
        require(bytes(title).length > 0, "Title Required");
        require(deadlineDays > 0, "Invalid Deadline");
        require(freelancer != msg.sender, "Cannot hire yourself");
        require(milestoneTitles.length == milestonePayments.length && milestoneTitles.length == milestoneDescriptions.length, "Milestone Arrays must match");
        require(milestoneTitles.length > 0, "need at least 1 milestone");
        require(arbiter1 != arbiter2 && arbiter2 != arbiter3 && arbiter1 != arbiter3, "Arbiter must be different");

        uint256 totalPayments = 0;
        for(uint256 i = 0; i< milestonePayments.length; i++){
            totalPayments += milestonePayments[i];
        }
        if(totalPayments != msg.value){
            revert TotalMilestonePaymentMismatch(totalPayments, msg.value);
        }

        jobId = ++jobCount;

        jobs[jobId] = Job({
            id: jobId,
            freelancer: freelancer,
            client: msg.sender,
            arbiter: arbiter1,
            payment: msg.value,
            deadline: block.timestamp + (deadlineDays * 1 days),
            status: JobStatus.Funded,
            title: title,
            description: description,
            createdAt: block.timestamp,
            submittedAt: 0,
            workProof: "",
            category: category,
            tags: new string[](0),
            paymentToken: address(0),
            tokenAmount: 0,
            isTokenPayment: false
        });

        for(uint256 i = 0; i < milestoneTitles.length; i++){
            jobMilestones[jobId].push(Milestone({
                id: i,
                title: milestoneTitles[i],
                description: milestoneDescriptions[i],
                payment: milestonePayments[i],
                status: MilestoneStatus.Pending,
                workProof: "",
                submittedAt: 0,
                approvedAt: 0
            }));
        }

        isMilestoneJob[jobId] = true;
        milestoneCount[jobId] = milestoneTitles.length;

        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(category)].push(jobId);
        allJobIds.push(jobId);
        jobsByStatus[uint8(JobStatus.Funded)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter1;
        arbiterVotes[jobId].arbiter2 = arbiter2;
        arbiterVotes[jobId].arbiter3 = arbiter3;

        _addToAutoRefund(jobId);

        emit JobCreated(jobId, msg.sender, msg.value, title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // Freelancer submits a specific milestone

    function submitMilestone(
        uint256 jobId,
        uint256 milestoneId,
        string memory workProof
    )
    external
    onlyFreelancer(jobId)
    whenNotPaused
    beforeDeadline(jobId)
    {
        if(!isMilestoneJob[jobId]) revert NotMilestoneJob();
        if(milestoneId >= jobMilestones[jobId].length) revert InvalidMilestoneId(milestoneId);
        require(bytes(workProof).length > 0, "Work Proof Required");

        Milestone storage m = jobMilestones[jobId][milestoneId];
        require(m.status == MilestoneStatus.Pending, "Milestone already submitted or approved");

        m.status = MilestoneStatus.Submitted;
        m.workProof = workProof;
        m.submittedAt = block.timestamp;

        emit MilestoneSubmitted(jobId, milestoneId, msg.sender, workProof);
    }

    // Client approves a milestone -> freelancer paid

    function approveMilestone(uint256 jobId, uint256 milestoneId)external onlyClient(jobId) whenNotPaused{
        if(!isMilestoneJob[jobId]) revert NotMilestoneJob();
        if(milestoneId >= jobMilestones[jobId].length) revert InvalidMilestoneId(milestoneId);

        Milestone storage m = jobMilestones[jobId][milestoneId];

        if(m.status == MilestoneStatus.Approved) revert MilestoneAlreadyApproved(milestoneId);
        if(m.status != MilestoneStatus.Submitted) revert MilestoneNotSubmitted(milestoneId);

        m.status = MilestoneStatus.Approved;
        m.approvedAt = block.timestamp;

        uint256 fee = (m.payment * platformFee)/ 10_000;
        uint256 payout = m.payment - fee;

        (bool ok1, ) = jobs[jobId].freelancer.call{value : payout}("");
        require(ok1, "Milestone Payment Failed");

        if(fee > 0){
            (bool ok2, ) = owner.call{value : fee}("");
            require(ok2, "Fee Payment Failed");
        }

        completedJobCount[jobs[jobId].freelancer]++;

        emit MilestoneApproved(jobId, milestoneId, jobs[jobId].freelancer, payout);
    }

    // Client disputes a milestone

    function disputeMilestone(uint256 jobId, uint256 milestoneId) external onlyClient(jobId){
        if(!isMilestoneJob[jobId]) revert NotMilestoneJob();
        if(milestoneId >= jobMilestones[jobId].length) revert InvalidMilestoneId(milestoneId);

        Milestone storage m = jobMilestones[jobId][milestoneId];
        require(m.status == MilestoneStatus.Submitted, "Milestone not submitted");

        m.status = MilestoneStatus.Disputed;

        emit MilestoneDisputed(jobId, milestoneId, msg.sender);
    }

    // Get all milestones for a job

    function getMilestones(uint256 jobId) external view returns(Milestone[] memory){
        return jobMilestones[jobId];
    }

    // Get specific milestone

    function getMilestone(uint256 jobId, uint256 milestoneId) external view returns(Milestone memory){
        require(milestoneId < jobMilestones[jobId].length, "Invalid Milestone");    
        return jobMilestones[jobId][milestoneId];
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

        // pay in ETH or token depending on job type

        if(job.isTokenPayment){
            _payWithToken(job.paymentToken, job.freelancer, job.tokenAmount, fee);
        }else{
            (bool ok1, ) = job.freelancer.call{value : payout}("");
            require(ok1, "Freelancer Payment Failed");

            if( fee > 0){
                (bool ok2, ) = owner.call{value : fee}("");
                require(ok2, "Fee Payment Failed");
            }
        }

        completedJobCount[job.freelancer]++;
        emit ReputationUpdated(job.freelancer, getReputationScore(job.freelancer));
        emit JobCompleted(jobId, job.freelancer, payout);
    }

    // Internal: pay with ERC-20 token

    function _payWithToken(address tokenAddress, address freelancer, uint256 tokenAmount, uint256) internal{
        IERC20 token = IERC20(tokenAddress);

        uint256 tokenFee = (tokenAmount * platformFee) / 10_000;
        uint256 tokenPayout = tokenAmount - tokenFee;

        bool ok1 = token.transfer(freelancer, tokenPayout);
        if(!ok1) revert TokenTransferFailed();

        if(tokenFee > 0){
            bool ok2 = token.transfer(owner, tokenFee);
            if(!ok2) revert TokenTransferFailed();
        }

        emit TokenPaymentReleased(0, freelancer, tokenAddress, tokenPayout);
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

        if(freelancerWins){
            disputesWon[job.freelancer]++;
            disputesLost[job.client]++;
        }else{
            disputesWon[job.client]++;
            disputesLost[job.freelancer]++;
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

        if(job.isTokenPayment){
            bool ok = IERC20(job.paymentToken).transfer(job.client, job.tokenAmount);
            if(!ok) revert TokenTransferFailed();
        }else{
            (bool ok,) = job.client.call{value : job.payment}("");
            require(ok, "Refund Failed");
        }

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

        if(job.isTokenPayment){
            bool ok = IERC20(job.paymentToken).transfer(job.client, job.tokenAmount);
            if(!ok) revert TokenTransferFailed();
        }else{
            (bool ok,) = job.client.call{value : job.payment}("");
            require(ok, "Refund Failed");
        }

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

        emit ReputationUpdated(jobs[jobId].freelancer, getReputationScore(jobs[jobId].freelancer));
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

        totalTipsReceived[jobs[jobId].freelancer]+= msg.value;

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

        if(freelancerWins){
            disputesWon[job.freelancer]++;
            disputesLost[job.client]++;
        }else{
            disputesWon[job.client]++;
            disputesLost[job.freelancer]++;
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

    // Creating Freelancer profile

    function createProfile (string memory name, string memory bio, string memory portfolioLink, string memory skills, uint256 hourlyRate) external {
        if(hasProfile[msg.sender]) revert ProfileAlreadyExists(msg.sender);
        require(bytes(name).length > 0, "Name Required");

        profiles[msg.sender] = Profile({
            name : name,
            bio : bio,
            portfolioLink : portfolioLink,
            skills : skills,
            hourlyRate : hourlyRate,
            available : true,
            createdAt : block.timestamp,
            updatedAt : block.timestamp
        });

        hasProfile[msg.sender] = true;

        emit ProfileCreated(msg.sender, name);
    }

    // Update your Profile

    function updateProfile(string memory bio, string memory portfolioLink, string memory skills, uint256 hourlyRate, bool available) external {
        if(!hasProfile[msg.sender]) revert ProfileNotFound(msg.sender);

        Profile storage p = profiles[msg.sender];
        p.bio = bio;
        p.portfolioLink = portfolioLink;
        p.skills = skills;
        p.hourlyRate = hourlyRate;
        p.available = available;
        p.updatedAt = block.timestamp;

        emit ProfileUpdated(msg.sender, block.timestamp);
    }

    // Get any profile

    function getProfile(address user) external view returns(Profile memory){
        if(!hasProfile[user]) revert ProfileNotFound(user);
        return profiles[user];
    }

    // Check if address has profile

    function profileExists(address user) external view returns(bool){
        return hasProfile[user];
    }

    // Get jobs by status

    function getJobsByStatus(JobStatus status) external view returns(uint256[] memory){
        return jobsByStatus[uint8(status)];
    }

    // Get all jobs with pagination

    function getJobsPaginated(uint256 offset, uint256 limit) external view returns(uint256[] memory result, uint256 total){
        total = allJobIds.length;
        if(offset >= total){
            return (new uint256[](0), total);
        }
        uint256 end = offset + limit;
        if(end > total) end = total;

        result = new uint256[](end - offset);
        for(uint256 i = offset; i < end; i++){
            result[i - offset] = allJobIds[i];
        }
    }

    // Get jobs within a budget range

    function getJobsByBudget(uint256 minBudget, uint256 maxBudget) external view returns(uint256[] memory){
        uint256 count = 0;
        for(uint256 i = 0; i < allJobIds.length; i++){
            uint256 jid = allJobIds[i];

            if(jobs[jid].payment >= minBudget && jobs[jid].payment <= maxBudget && jobs[jid].status == JobStatus.Funded){
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        for(uint256 i = 0; i < allJobIds.length; i++){
            uint256 jid = allJobIds[i];
            if(jobs[jid].payment >= minBudget && jobs[jid].payment <= maxBudget && jobs[jid].status == JobStatus.Funded){
                result[idx++] = jid;
            }
        }
        return result;
    }

    // Get all OPEN (Funded) jobs

    function getOpenJobs() external view returns(uint256[] memory){
        return jobsByStatus[uint8(JobStatus.Funded)];
    }

    // Get total jobs count

    function getTotalJobs() external view returns(uint256){
        return allJobIds.length;
    }

    // AUTO REFUND (Chainlink Automation)

    // Internal: add job to auto refund list

    function _addToAutoRefund(uint256 jobId) internal{
        if(!addedToAutoRefund[jobId]){
            autoRefundEligible.push(jobId);
            addedToAutoRefund[jobId] = true;
        }
    }

    // Chainlink calls this to check if work needed

    function checkUpKeep(bytes calldata) external view override returns(bool upKeepNeeded, bytes memory performData){
        for(uint256 i = 0; i < autoRefundEligible.length; i++){
            uint256 jobId = autoRefundEligible[i];
            Job storage job = jobs[jobId];

            if(block.timestamp > job.deadline && (job.status == JobStatus.Funded || job.status == JobStatus.Started)){
                upKeepNeeded = true;
                performData = abi.encode(jobId);
                return(upKeepNeeded, performData);
            }
        }
        return(false, "");
    }

    // Chainlink calls this to execute the refund

    function performUpKeep(bytes calldata performData) external override{
        uint256 jobId = abi.decode(performData, (uint256));
        Job storage job = jobs[jobId];

        require(block.timestamp > job.deadline, "Deadline Not Passed");
        require(job.status == JobStatus.Funded || job.status == JobStatus.Started, "Cannot auto refund at this stage");

        job.status = JobStatus.Refunded;

        if(job.isTokenPayment){
            bool ok = IERC20(job.paymentToken).transfer(job.client, job.tokenAmount);
            require(ok, "Token Refund Failed");
        }else{
            (bool ok, ) = job.client.call{value : job.payment}("");
            require(ok, "Auto Refund Failed");
        }

        emit AutoRefundExecuted(jobId, job.client, job.payment);
        emit JobCancelled(jobId, address(this));
    }

    // REPUTATION SCORE

    // Calculate reputation score (0 to 100)

    function getReputationScore(address user) public view returns(uint256 score){
        // Component 1: Completed jobs (max 40 points)
        // 1 job = 2 points, max 40 points (20 jobs)

        uint256 jobScore = completedJobCount[user] * 2;
        if(jobScore > 40) jobScore = 40;

        // Component 2: Average rating (max 30 points)
        // 5 stars = 30 points, 1 star = 6 points

        Rating[] memory ratings = freelancerRatings[user];
        uint256 ratingScore = 0;
        if(ratings.length > 0){
            uint256 totalStars = 0;
            for(uint i = 0; i < ratings.length; i++){
                totalStars += ratings[i].score;
            }
            uint256 avgStars = totalStars/ratings.length;
            ratingScore = avgStars * 6;
        }

        // Component 3: Dispute record (max 20 points)
        // Each win = +2 points, each loss = -3 points

        uint256 disputeScore = 0;
        uint256 wins = disputesWon[user];
        uint256 losses = disputesLost[user];

        if(wins * 2 > losses * 3){
            disputeScore = (wins * 2) - (losses * 3);
        }
        if(disputeScore > 20) disputeScore = 20;

        // Component 4: Tips received (max 10 points)
        // Every 0.1 ETH in tips = 1 point, max 10

        uint256 tipScore = totalTipsReceived[user]/0.1 ether;
        if(tipScore > 10) tipScore = 10;

        score = jobScore + ratingScore + disputeScore + tipScore;
        if(score > 100) score = 100;
    }

    // Get full reputation breakdown

    function getReputationBreakdown(address user) external view returns(uint256 totalScore, uint256 jobsCompleted, uint256 averageRating, uint256 diputesWin, uint256 diputesLost, uint256 tipsReceivedWei){
        totalScore = getReputationScore(user);
        jobsCompleted = completedJobCount[user];
        diputesWin = disputesWon[user];
        diputesLost = disputesLost[user];
        tipsReceivedWei = totalTipsReceived[user];

        Rating[] memory ratings = freelancerRatings[user];
        if(ratings.length > 0){
            uint256 total = 0;
            for(uint256 i = 0; i < ratings.length; i++){
                total += ratings[i].score;
            }

            averageRating = (total * 10) / ratings.length;
        }
    }

    // Get reputation level as string

    function getReputationLevel(address user) external view returns(string memory level){
        uint256 score = getReputationScore(user);

        if(score >= 90) return "Diamond";
        if(score >= 75) return "Gold";
        if(score >= 50) return "Silver";
        if(score >= 25) return "Bronze";
        return "New Comer";
    }

    // JOB TEMPLATES

    // Save a job template

    function saveTemplate(string memory title, string memory description, Category category, uint256 defaultDeadlineDays, uint256 defaultBudget) external returns (uint256 templateId){
        require(bytes(title).length > 0, "Title Required");
        require(defaultDeadlineDays > 0, "Invalid Deadline Days");

        templateId = ++templateCount;
        
        templates[templateId] = JobTemplate({
            id : templateId,
            title : title,
            description : description,
            category : category,
            defaultDeadlineDays : defaultDeadlineDays,
            defaultBudget : defaultBudget,
            owner : msg.sender,
            isActive : true,
            createdAt : block.timestamp
        });

        myTemplates[msg.sender].push(templateId);

        emit TemplateCreated(templateId, msg.sender, title);
    }

    // Delete (deactivate) a template

    function deleteTemplate(uint256 templateId) external{
        if(templateId == 0 || templateId > templateCount) revert TemplateNotFound(templateId);
        if(templates[templateId].owner != msg.sender) revert NotTemplateOwner(msg.sender);

        templates[templateId].isActive = false;

        emit TemplateDeleted(templateId, msg.sender);
    }

    // Create a job using a saved template

    function createJobFromTemplate(uint256 templateId, address freelancer, address arbiter1, address arbiter2, address arbiter3, string[] memory tags) external payable whenNotPaused validAddress(freelancer) validAddress(arbiter1) validAddress(arbiter2) validAddress(arbiter3) returns(uint256 jobId){
        if(templateId == 0 || templateId > templateCount) revert TemplateNotFound(templateId);
        JobTemplate memory tmpl = templates[templateId];

        if(!tmpl.isActive) revert TemplateInactive(templateId);
        require(msg.value > 0, "Must fund the job");
        require(freelancer != msg.sender, "Cannot hire yourself");
        require(arbiter1 != arbiter2 && arbiter2 != arbiter3 && arbiter3 != arbiter1, "Arbiter must be different");

        jobId = ++jobCount;

        jobs[jobId] = Job({
            id : jobId,
            client : msg.sender,
            freelancer : freelancer,
            arbiter : arbiter1,
            payment : msg.value,
            deadline : block.timestamp + (tmpl.defaultDeadlineDays * 1 days),
            status : JobStatus.Funded,
            title : tmpl.title,
            description : tmpl.description,
            createdAt : block.timestamp,
            submittedAt : 0,
            workProof : "",
            category : tmpl.category,
            tags : new string[](0),
            paymentToken : address(0),
            tokenAmount : 0,
            isTokenPayment : false
        });

        for(uint256 i = 0; i < tags.length; i++){
            jobs[jobId].tags.push(tags[i]);
        }

        clientJobs[msg.sender].push(jobId);
        freelancerJobs[freelancer].push(jobId);
        jobsByCategory[uint256(tmpl.category)].push(jobId);
        allJobIds.push(jobId);
        jobsByStatus[uint8(JobStatus.Funded)].push(jobId);

        arbiterVotes[jobId].arbiter1 = arbiter1;
        arbiterVotes[jobId].arbiter2 = arbiter2;
        arbiterVotes[jobId].arbiter3 = arbiter3;

        _addToAutoRefund(jobId);

        emit JobCreatedFromTemplate(jobId, templateId);
        emit JobCreated(jobId, msg.sender, msg.value, tmpl.title);
        emit JobFunded(jobId, msg.sender, msg.value);
    }

    // Get a specific template

    function getTemplate(uint256 templateId) external view returns(JobTemplate memory){
        if(templateId == 0 || templateId > templateCount) revert TemplateNotFound(templateId);
        return templates[templateId];
    }

    // Get all templates created by an address

    function getMyTemplate(address user) external view returns(uint256[] memory){
        return myTemplates[user];
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
