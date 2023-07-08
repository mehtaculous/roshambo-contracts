// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "src/Roshambo.sol";
import "src/interfaces/IRoshambo.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract RoshamboTest is Test {
    // Contracts
    Renderer renderer;
    Recorder recorder;
    Roshambo roshambo;
    PaymentSplitter splitter;

    // Users
    address alice;
    address bob;
    address eve;
    address susan;

    // Game
    Player p1;
    Player p2;
    Stage stage;
    uint8 totalRounds;
    uint8 currentRound;
    uint72 pot;
    address gameWinner;

    // Round
    Choice p1Choice;
    Choice p2Choice;
    uint40 commitBlock;
    uint40 revealBlock;
    address roundWinner;

    // Record
    uint64 playerId;
    uint48 roundsWon;
    uint48 seriesWon;
    uint48 roundsLost;
    uint48 seriesLost;
    uint128 wagers;
    uint128 profits;

    // State
    address beneficiary;
    bytes32 commitment;
    uint40 gameId;
    uint40 totalSupply;
    uint72 rake;
    uint256 adjusted;
    address[] payees;
    uint256[] shares;

    // Constants
    uint8 constant ROUNDS = 3;
    uint16 constant RAKE = 250;
    uint256 constant BALANCE = 1000 ether;
    uint256 constant BLOCK_DURATION = 6969;
    uint256 constant MIN_WAGER = 0.01 ether;
    string constant BLOCK = "block";
    string constant PAPER = "paper";
    string constant SCISSORS = "scissors";

    // Errors
    bytes4 constant ALREADY_COMMITTED_ERROR = 0xbfec5558;
    bytes4 constant ALREADY_REVEALED_ERROR = 0xa89ac151;
    bytes4 constant INSUFFICIENT_BALANCE_ERROR = 0xf4d678b8;
    bytes4 constant INSUFFICIENT_WAGER_ERROR = 0x9913e90e;
    bytes4 constant INVALID_CHOICE_ERROR = 0x9c454001;
    bytes4 constant INVALID_GAME_ERROR = 0x57e25a09;
    bytes4 constant INVALID_PLAYER_ERROR = 0x0e8a471c;
    bytes4 constant INVALID_REVEAL_ERROR = 0x9ea6d127;
    bytes4 constant INVALID_ROUNDS_ERROR = 0x0ebd7195;
    bytes4 constant INVALID_STAGE_ERROR = 0xe82a5329;
    bytes4 constant INVALID_WAGER_ERROR = 0x2f763a01;
    bytes4 constant TIME_ELAPSED_ERROR = 0x054eca3f;
    bytes4 constant TRANSFER_FAILED_ERROR = 0x90b8ec18;

    /// =====================
    /// ===== MODIFIERS =====
    /// =====================

    modifier prank(address _sender) {
        vm.startPrank(_sender);
        _;
        vm.stopPrank();
    }

    receive() external payable {}

    /// =================
    /// ===== SETUP =====
    /// =================

    function setUp() public {
        alice = _createUser("alice");
        bob = _createUser("bob");
        eve = _createUser("eve");
        susan = _createUser("susan");
        setUpSplitter();

        renderer = new Renderer();
        splitter = new PaymentSplitter(payees, shares);
        roshambo = new Roshambo(renderer, address(splitter));
        recorder = roshambo.recorder();
        beneficiary = roshambo.beneficiary();
        roshambo.setRake(RAKE);

        vm.label(address(recorder), "Recorder");
        vm.label(address(renderer), "Renderer");
        vm.label(address(roshambo), "Roshambo");
        vm.label(address(splitter), "PaymentSplitter");
        vm.label(address(this), "RoshamboTest");
    }

    /// ====================
    /// ===== NEW GAME =====
    /// ====================

    function testNewGame() public {
        // setup
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // execute
        _newGame(alice, ROUNDS, commitment, MIN_WAGER);
        // assert
        assertEq(p1.player, alice);
        assertEq(p1.commitment, commitment);
        assertEq(uint8(p1Choice), uint8(Choice.HIDDEN));
        assertEq(uint8(stage), uint8(Stage.PENDING));
        assertEq(pot, MIN_WAGER);
    }

    function testNewGameRevertInsufficientWager(uint256 _wager) public {
        // setup
        vm.assume(_wager < MIN_WAGER);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INSUFFICIENT_WAGER_ERROR);
        // execute
        _newGame(alice, ROUNDS, commitment, _wager);
    }

    function testNewGameRevertInvalidRounds(uint8 _rounds) public {
        // setup
        vm.assume(_rounds % 2 == 0);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INVALID_ROUNDS_ERROR);
        // execute
        _newGame(alice, ROUNDS + 1, commitment, MIN_WAGER);
    }

    /// =====================
    /// ===== JOIN GAME =====
    /// =====================

    function testJoinGame() public {
        // setup
        testNewGame();
        _setCommit(bob, Choice.PAPER, PAPER);
        // execute
        _joinGame(bob, gameId, commitment, MIN_WAGER);
        // assert
        assertEq(p2.player, bob);
        assertEq(p2.commitment, commitment);
        assertEq(uint8(p2Choice), uint8(Choice.HIDDEN));
        assertEq(pot, MIN_WAGER * 2);
        assertEq(uint8(stage), uint8(Stage.REVEAL));
        assertEq(roshambo.ownerOf(gameId), address(roshambo));
    }

    function testJoinGameRevertInvalidGame(uint40 _gameId) public {
        // setup
        testNewGame();
        vm.assume(_gameId > gameId);
        _setCommit(bob, Choice.PAPER, PAPER);
        // revert
        vm.expectRevert(INVALID_GAME_ERROR);
        // execute
        _joinGame(bob, _gameId, commitment, MIN_WAGER);
    }

    function testJoinGameRevertInvalidStage() public {
        // setup
        testJoinGame();
        _setCommit(bob, Choice.PAPER, PAPER);
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _joinGame(bob, gameId, commitment, MIN_WAGER);
    }

    function testJoinGameRevertInvalidPlayer() public {
        // setup
        testNewGame();
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INVALID_PLAYER_ERROR);
        // execute
        _joinGame(alice, gameId, commitment, MIN_WAGER);
    }

    function testJoinGameRevertInvalidWager(uint88 _wager) public {
        // setup
        testNewGame();
        vm.assume(_wager != MIN_WAGER && _wager < BALANCE);
        _setCommit(bob, Choice.PAPER, PAPER);
        // revert
        vm.expectRevert(INVALID_WAGER_ERROR);
        // execute
        _joinGame(bob, gameId, commitment, _wager);
    }

    /// ==================
    /// ===== COMMIT =====
    /// ==================

    function testCommit() public {
        // setup
        setUpGame(MIN_WAGER);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // execute
        _commit(alice, gameId, commitment);
        // assert
        assertEq(p1.commitment, commitment);
        assertEq(uint8(p1Choice), uint8(Choice.HIDDEN));
        assertEq(uint8(stage), uint8(Stage.COMMIT));
        assertEq(commitBlock, block.number + BLOCK_DURATION);

        // setup
        _setCommit(bob, Choice.PAPER, PAPER);
        // execute
        _commit(bob, gameId, commitment);
        // assert
        assertEq(p2.commitment, commitment);
        assertEq(uint8(p2Choice), uint8(Choice.HIDDEN));
        assertEq(uint8(stage), uint8(Stage.REVEAL));
        assertEq(revealBlock, block.number + BLOCK_DURATION);
    }

    function testCommitRevertInvalidGame(uint40 _gameId) public {
        // setup
        setUpGame(MIN_WAGER);
        vm.assume(_gameId > gameId);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INVALID_GAME_ERROR);
        // execute
        _commit(alice, _gameId, commitment);
    }

    function testCommitRevertInvalidStage() public {
        // setup
        testJoinGame();
        _setCommit(alice, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _commit(alice, gameId, commitment);
    }

    function testCommitRevertTimeElapsed() public {
        // setup
        setUpGame(MIN_WAGER);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _commit(alice, gameId, commitment);
        vm.roll(commitBlock + 1);
        _setCommit(bob, Choice.PAPER, PAPER);
        // revert
        vm.expectRevert(TIME_ELAPSED_ERROR);
        // execute
        _commit(bob, gameId, commitment);
    }

    function testCommitRevertAlreadyCommitted() public {
        // setup
        setUpGame(MIN_WAGER);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _commit(alice, gameId, commitment);
        // revert
        vm.expectRevert(ALREADY_COMMITTED_ERROR);
        // execute
        _commit(alice, gameId, commitment);
    }

    /// ==================
    /// ===== REVEAL =====
    /// ==================

    function testReveal() public {
        // setup
        testJoinGame();
        // execute
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        // assert
        assertEq(uint8(p1Choice), uint8(Choice.BLOCK));
        assertEq(uint8(stage), uint8(Stage.REVEAL));
        assertEq(revealBlock, block.number + BLOCK_DURATION);
    }

    function testRevealRevertInvalidGame(uint40 _gameId) public {
        // setup
        testJoinGame();
        vm.assume(_gameId > gameId);
        // revert
        vm.expectRevert(INVALID_GAME_ERROR);
        // execute
        vm.prank(alice);
        roshambo.reveal(_gameId, Choice.BLOCK, BLOCK);
    }

    function testRevealRevertInvalidStage() public {
        // setup
        testNewGame();
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
    }

    function testRevealRevertTimeElapsed() public {
        // setup
        testJoinGame();
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        vm.roll(revealBlock + 1);
        // revert
        vm.expectRevert(TIME_ELAPSED_ERROR);
        // execute
        _reveal(bob, gameId, Choice.PAPER, PAPER);
    }

    function testRevealRevertAlreadyRevealed() public {
        // setup
        testJoinGame();
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(ALREADY_REVEALED_ERROR);
        // execute
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
    }

    function testRevealRevertInvalidRevealChoice() public {
        // setup
        testJoinGame();
        // revert
        vm.expectRevert(INVALID_REVEAL_ERROR);
        // execute
        _reveal(alice, gameId, Choice.PAPER, BLOCK);
    }

    function testRevealRevertInvalidRevealSecret() public {
        // setup
        testJoinGame();
        // revert
        vm.expectRevert(INVALID_REVEAL_ERROR);
        // execute
        _reveal(alice, gameId, Choice.BLOCK, PAPER);
    }

    /// ==================
    /// ===== SETTLE =====
    /// ==================

    function testSettleSuccessful() public {
        // setup
        setUpGame(MIN_WAGER);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(gameWinner, bob);
        assertEq(p2.wins, ROUNDS / 2 + 1);
        assertEq(uint8(stage), uint8(Stage.SUCCESS));
        assertEq(uint8(p1Choice), uint8(Choice.BLOCK));
        assertEq(uint8(p2Choice), uint8(Choice.PAPER));
        assertEq(roshambo.ownerOf(gameId), bob);
        assertEq(roshambo.balances(alice), 0);
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);

        // setup
        _setRecord(alice);
        // assert
        assertEq(roundsWon, 0);
        assertEq(seriesWon, 0);
        assertEq(roundsLost, 2);
        assertEq(seriesLost, 1);
        assertEq(wagers, MIN_WAGER);
        assertEq(profits, 0);

        // setup
        _setRecord(bob);
        // assert
        assertEq(roundsWon, 2);
        assertEq(seriesWon, 1);
        assertEq(roundsLost, 0);
        assertEq(seriesLost, 0);
        assertEq(wagers, MIN_WAGER);
        assertEq(profits, MIN_WAGER);
    }

    function testSettleDraw() public {
        // setup
        setUpDraw(MIN_WAGER);
        vm.roll(commitBlock + 1);
        // execute
        _settle(gameId);
        // assert
        assertEq(gameWinner, address(0));
        assertEq(uint8(stage), uint8(Stage.DRAW));
        assertEq(uint8(p1Choice), uint8(Choice.NONE));
        assertEq(uint8(p2Choice), uint8(Choice.NONE));
        assertEq(roshambo.ownerOf(gameId), address(roshambo));
        assertEq(roshambo.balances(alice), pot / 2);
        assertEq(roshambo.balances(bob), pot / 2);
        assertEq(roshambo.balances(beneficiary), 0);
    }

    function testSettleResetRound() public {
        // setup
        setUpGame(MIN_WAGER);
        vm.roll(commitBlock + 1);
        // execute
        _settle(gameId);
        // assert
        assertEq(currentRound, 2);
        assertEq(gameWinner, address(0));
        assertEq(uint8(stage), uint8(Stage.COMMIT));
        assertEq(uint8(p1Choice), uint8(Choice.NONE));
        assertEq(uint8(p2Choice), uint8(Choice.NONE));

        // setup
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _commit(alice, gameId, commitment);
        _setCommit(bob, Choice.PAPER, PAPER);
        _commit(bob, gameId, commitment);
        vm.roll(revealBlock + 1);
        // execute
        _settle(gameId);
        // assert
        assertEq(currentRound, 2);
        assertEq(gameWinner, address(0));
        assertEq(uint8(stage), uint8(Stage.COMMIT));
        assertEq(uint8(p1Choice), uint8(Choice.NONE));
        assertEq(uint8(p2Choice), uint8(Choice.NONE));
    }

    function testSettleRevertInvalidStagePending() public {
        // setup
        testNewGame();
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _settle(gameId);
    }

    function testSettleRevertInvalidStageCommit() public {
        // setup
        setUpGame(MIN_WAGER);
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _commit(alice, gameId, commitment);
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _settle(gameId);
    }

    function testSettleRevertInvalidStageReveal() public {
        // setup
        testJoinGame();
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _settle(gameId);
    }

    /// ================
    /// ===== RAKE =====
    /// ================

    function testRake() public {
        // setup
        setUpGame(0.25 ether);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);

        // setup
        _withdraw(bob);
        _withdraw(beneficiary);
        setUpGame(0.5 ether);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);

        // setup
        _withdraw(bob);
        _withdraw(beneficiary);
        setUpGame(2.5 ether);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);

        // setup
        _withdraw(bob);
        _withdraw(beneficiary);
        setUpGame(5 ether);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);

        // setup
        _withdraw(bob);
        _withdraw(beneficiary);
        setUpGame(500 ether);
        for (uint256 i; i < ROUNDS / 2; ++i) setUpRound();
        // assert
        assertEq(roshambo.balances(bob), pot - rake);
        assertEq(roshambo.balances(beneficiary), rake);
    }

    /// ==================
    /// ===== CANCEL =====
    /// ==================

    function testCancel() public {
        // setup
        testNewGame();
        // execute
        _cancel(alice, gameId);
        // assert
        assertEq(alice.balance, BALANCE);
        assertEq(p1.player, address(0));
        assertEq(pot, 0);
        assertEq(uint8(stage), uint8(Stage.PENDING));
    }

    function testCancelRevertInvalidStage() public {
        // setup
        testJoinGame();
        // revert
        vm.expectRevert(INVALID_STAGE_ERROR);
        // execute
        _cancel(alice, gameId);
    }

    function testCancelRevertInvalidPlayer() public {
        // setup
        testNewGame();
        // revert
        vm.expectRevert(INVALID_PLAYER_ERROR);
        // execute
        _cancel(bob, gameId);
    }

    /// ====================
    /// ===== WITHDRAW =====
    /// ====================

    function testWithdraw() public {
        // setup
        testSettleSuccessful();
        // execute
        _withdraw(bob);
        _withdraw(beneficiary);
        // assert
        assertEq(bob.balance, BALANCE + (pot / 2) - rake);
        assertEq(beneficiary.balance, rake);
    }

    function testWithdrawRevertInsufficientBalance() public {
        // setup
        testReveal();
        // revert
        vm.expectRevert(INSUFFICIENT_BALANCE_ERROR);
        // execute
        _withdraw(bob);
    }

    /// ===========================
    /// ===== SET BENEFICIARY =====
    /// ===========================

    function testSetBeneficiary() public {
        // setup
        roshambo.setBeneficiary(susan);
        // execute
        assertEq(roshambo.beneficiary(), susan);
    }

    /// ====================
    /// ===== SET RAKE =====
    /// ====================

    function testSetRake() public {
        // setup
        roshambo.setRake(300);
        // execute
        assertEq(roshambo.rake(), 300);
    }

    /// =====================
    /// ===== TOKEN URI =====
    /// =====================

    function testTokenURI() public {
        // setup
        _setCommit(alice, Choice.PAPER, PAPER);
        _newGame(alice, 1, commitment, MIN_WAGER);
        _setCommit(bob, Choice.SCISSORS, SCISSORS);
        _joinGame(bob, gameId, commitment, MIN_WAGER);
        // execute
        roshambo.tokenURI(gameId);
    }

    /// ====================
    /// ===== RENDERER =====
    /// ====================

    function testRenderer() public view {
        renderer.generateImage(gameId, 0.1 ether, alice, Choice.NONE, bob, Choice.NONE);
        renderer.generateImage(gameId, 0.5 ether, alice, Choice.HIDDEN, bob, Choice.HIDDEN);
        renderer.generateImage(gameId, 1.0 ether, alice, Choice.BLOCK, bob, Choice.PAPER);
        renderer.generateImage(gameId, 2.5 ether, alice, Choice.PAPER, bob, Choice.SCISSORS);
        renderer.generateImage(gameId, 5.0 ether, alice, Choice.SCISSORS, bob, Choice.BLOCK);
    }

    /// ===================
    /// ===== HELPERS =====
    /// ===================

    function _createUser(string memory _name) internal returns (address user) {
        user = address(uint160(uint256(keccak256(abi.encodePacked(_name)))));
        vm.label(user, _name);
        vm.deal(user, BALANCE);
    }

    function setUpSplitter() public {
        payees = new address[](4);
        shares = new uint256[](4);
        payees[0] = alice;
        payees[1] = bob;
        payees[2] = eve;
        payees[3] = susan;
        shares[0] = 25;
        shares[1] = 25;
        shares[2] = 25;
        shares[3] = 25;
    }

    function setUpGame(uint256 _wager) public {
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _newGame(alice, ROUNDS, commitment, _wager);
        _setCommit(bob, Choice.PAPER, PAPER);
        _joinGame(bob, gameId, commitment, _wager);
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        _reveal(bob, gameId, Choice.PAPER, PAPER);
    }

    function setUpRound() public {
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _commit(alice, gameId, commitment);
        _setCommit(bob, Choice.PAPER, PAPER);
        _commit(bob, gameId, commitment);
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        _reveal(bob, gameId, Choice.PAPER, PAPER);
    }

    function setUpDraw(uint256 _wager) public {
        _setCommit(alice, Choice.BLOCK, BLOCK);
        _newGame(alice, ROUNDS, commitment, _wager);
        _setCommit(bob, Choice.BLOCK, BLOCK);
        _joinGame(bob, gameId, commitment, _wager);
        _reveal(alice, gameId, Choice.BLOCK, BLOCK);
        _reveal(bob, gameId, Choice.BLOCK, BLOCK);
    }

    function _setCommit(address _player, Choice _choice, string memory _secret) internal {
        commitment = roshambo.getCommit(_player, _choice, _secret);
    }

    function _newGame(
        address _player,
        uint8 _rounds,
        bytes32 _commitment,
        uint256 _wager
    ) internal prank(_player) {
        gameId = roshambo.newGame{value: _wager}(_rounds, _commitment);
        _setGame(gameId);
        _setRound(gameId, currentRound);
    }

    function _joinGame(
        address _player,
        uint40 _gameId,
        bytes32 _commitment,
        uint256 _wager
    ) internal prank(_player) {
        roshambo.joinGame{value: _wager}(_gameId, _commitment);
        totalSupply = roshambo.totalSupply();
        _setGame(_gameId);
        _setRound(gameId, currentRound);
    }

    function _commit(address _player, uint40 _gameId, bytes32 _commitment) internal prank(_player) {
        roshambo.commit(_gameId, _commitment);
        if (gameId == _gameId) _setRound(gameId, currentRound);
        _setGame(_gameId);
        _setRound(gameId, currentRound);
    }

    function _reveal(
        address _player,
        uint40 _gameId,
        Choice _choice,
        string memory _secret
    ) internal prank(_player) {
        roshambo.reveal(_gameId, _choice, _secret);
        _adjustRake(uint256(pot), uint256(RAKE));
        _setGame(_gameId);
        _setRound(gameId, currentRound);
    }

    function _settle(uint40 _gameId) internal {
        roshambo.settle(_gameId);
        _adjustRake(uint256(pot), uint256(RAKE));
        _setGame(_gameId);
        _setRound(gameId, currentRound);
    }

    function _cancel(address _player, uint40 _gameId) internal prank(_player) {
        roshambo.cancel(_gameId);
        _setGame(_gameId);
    }

    function _withdraw(address _to) internal {
        roshambo.withdraw(_to);
    }

    function _setGame(uint40 _gameId) internal {
        (p1, p2, stage, totalRounds, currentRound, pot, gameWinner) = roshambo.games(_gameId);
    }

    function _setRound(uint40 _gameId, uint8 _round) internal {
        (p1Choice, p2Choice, commitBlock, revealBlock, roundWinner) = roshambo.getRound(
            _gameId,
            _round
        );
    }

    function _setRecord(address _player) internal {
        (playerId, roundsWon, seriesWon, roundsLost, seriesLost, wagers, profits) = recorder
            .records(_player);
    }

    function _adjustRake(uint256 _pot, uint256 _rake) internal {
        adjusted = recorder.adjustRake(_pot, _rake);
        rake = uint72((_pot * adjusted) / 10_000);
    }

    function _tokenURI(uint256 _gameId) internal view {
        roshambo.tokenURI(_gameId);
    }
}
