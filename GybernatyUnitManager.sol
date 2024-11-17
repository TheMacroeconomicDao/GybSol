// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Импортируем интерфейс для работы с ERC20 токенами
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Контракт GybernatyUnitManager для управления уровнями пользователей
contract GybernatyUnitManager {
    // Структура для хранения информации о пользователях
    struct User {
        // Адрес пользователя
        address userAddress;
        // Имя пользователя (опциональное)
        string name;
        // Ссылка пользователя (опциональное)
        string link;
        // Флаг, указывающий, отмечен ли пользователь для повышения уровня
        bool markedUp;
        // Флаг, указывающий, отмечен ли пользователь для понижения уровня
        bool markedDown;
        // Текущий уровень пользователя
        uint32 level;
        // Флаг, указывающий, ожидает ли пользователь подтверждения создания
        bool pendingCreation;
    }

    // Максимальный уровень пользователя (константа)
    uint32 public constant maxLevel = 4;
    // Количество Gbr токенов, необходимое для вступления в категорию Gybernaty
    uint256 public constant GbrTokenAmount = 1_000_000_000_000;
    // Адрес контракта Gbr токенов
    IERC20 public constant GbrToken = IERC20(0xA970cAE9Fa1D7Cca913b7C19DF45BF33d55384A9);
    // Количество BNB, необходимое для вступления в категорию Gybernaty
    uint256 public constant BnbAmount = 1000 ether;

    // Маппинг для хранения информации о пользователях по их адресам
    mapping (address => User) public users;
    // Маппинг для хранения адресов, входящих в категорию Gybernaty
    mapping (address => bool) public gybernaties;

    // События контракта
    event UserMarkUp(address userAddress);
    event UserMarkDown(address userAddress);
    event UserLevelUp(address userAddress);
    event UserLevelDown(address userAddress);
    event GybernatyJoined(address gybernatyAddress);
    event UserCreationRequested(address userAddress);
    event UserCreationConfirmed(address userAddress);

    // Ошибки контракта
    error OnlyGybernaty();
    error LevelInvalid();
    error UserExists();
    error UserNotFound();
    error UserNotMarked();
    error MinLevel();
    error MaxLevel();
    error InsufficientFunds();
    error InsufficientApprovals();

    // Модификатор для проверки, является ли вызывающий адрес членом категории Gybernaty
    modifier onlyGybernaty() {
        if (!gybernaties[msg.sender]) {
            revert OnlyGybernaty();
        }
        _;
    }

    // Конструктор контракта
    constructor() {
        // Контракт не имеет прав только владельца (onlyOwner)
    }

    /**
     * Функция для вступления в категорию Gybernaty
     * @dev Адрес, отправивший достаточное количество Gbr токенов или BNB, становится членом Gybernaty
     */
    function joinGybernaty() public payable {
        // Проверяем, отправлено ли достаточное количество Gbr токенов или BNB
        if (msg.value < BnbAmount && GbrToken.balanceOf(msg.sender) < GbrTokenAmount) {
            revert InsufficientFunds();
        }

        // Добавляем адрес в категорию Gybernaty
        gybernaties[msg.sender] = true;

        // Вызываем событие о вступлении в категорию Gybernaty
        emit GybernatyJoined(msg.sender);
    }

    /**
     * Функция для заявления данных для создания пользователя
     * @param name Имя пользователя (опциональное)
     * @param link Ссылка пользователя (опциональное)
     */
    function requestUserCreation(string memory name, string memory link) public {
        address userAddress = msg.sender;

        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress != address(0)) {
            revert UserExists();
        }

        // Создаем нового пользователя с пустым уровнем и отметкой ожидания подтверждения
        User memory user = User(
            userAddress,
            name,
            link,
            false,
            false,
            0,
            true
        );

        // Добавляем пользователя в маппинг
        users[userAddress] = user;

        // Вызываем событие о заявке на создание пользователя
        emit UserCreationRequested(userAddress);
    }

    /**
     * Функция для подтверждения создания пользователя
     * @param userAddress Адрес пользователя
     * @param level Начальный уровень пользователя
     * @param approver1 Адрес первого подтверждающего
     * @param approver2 Адрес второго подтверждающего (если требуется)
     * @param approver3 Адрес третьего подтверждающего (если требуется)
     */
    function confirmUserCreation(address userAddress, uint32 level, address approver1, address approver2, address approver3) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, является ли указанный уровень действительным
        if (level < 1 || level > maxLevel) {
            revert LevelInvalid();
        }

        // Проверяем, ожидает ли пользователь подтверждения создания
        if (!users[userAddress].pendingCreation) {
            revert UserNotFound();
        }

        // Подтверждение создания пользователя
        if (gybernaties[approver1] && (level == 1 || level == 2)) {
            // Подтверждение одного Gybernaty для уровней 1 и 2
            users[userAddress].level = level;
            users[userAddress].pendingCreation = false;
            emit UserCreationConfirmed(userAddress);
            emit UserLevelUp(userAddress);
        } else if (gybernaties[approver1] && gybernaties[approver2] && (level == 3)) {
            // Подтверждение двух Gybernaty для уровня 3
            users[userAddress].level = level;
            users[userAddress].pendingCreation = false;
            emit UserCreationConfirmed(userAddress);
            emit UserLevelUp(userAddress);
        } else if (gybernaties[approver1] && gybernaties[approver2] && gybernaties[approver3] && (level == 4)) {
            // Подтверждение трех Gybernaty для уровня 4
            users[userAddress].level = level;
            users[userAddress].pendingCreation = false;
            emit UserCreationConfirmed(userAddress);
            emit UserLevelUp(userAddress);
        } else {
            revert InsufficientApprovals();
        }
    }

    /**
     * Функция для отметки пользователя для повышения уровня
     * @dev Пользователи могут отмечать себя для повышения уровня
     */
    function userMarkUp() public {
        address userAddress = msg.sender;

        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserExists(); // Пользователь уже существует, поэтому не может отмечать себя повторно
        }

        // Проверяем, имеет ли пользователь максимальный уровень
        if (users[userAddress].level == maxLevel) {
            revert MaxLevel();
        }

        // Отмечаем пользователя для повышения уровня
        users[userAddress].markedUp = true;

        // Вызываем событие об отмечке для повышения уровня
        emit UserMarkUp(userAddress);
    }

    /**
     * Функция для отметки пользователя для понижения уровня
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут отметки пользователей для понижения уровня
     */
    function userMarkDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, имеет ли пользователь минимальный уровень
        if (users[userAddress].level == 1) {
            revert MinLevel();
        }

        // Отмечаем пользователя для понижения уровня
        users[userAddress].markedDown = true;

        // Вызываем событие об отмечке для понижения уровня
        emit UserMarkDown(userAddress);
    }

    /**
     * Функция для повышения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут повышать уровень пользователей
     */
    function userLevelUp(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для повышения уровня
        if (!users[userAddress].markedUp) {
            revert UserNotMarked();
        }

        // Повышаем уровень пользователя
        users[userAddress].level += 1;

        // Сброс отметок пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о повышении уровня
        emit UserLevelUp(userAddress);
    }

    /**
     * Функция для понижения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут понижать уровень пользователей
     */
    function userLevelDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для понижения уровня
        if (!users[userAddress].markedDown) {
            revert UserNotMarked();
        }

        // Понижаем уровень пользователя
        users[userAddress].level -= 1;

        // Сброс отметок пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о понижении уровня
        emit UserLevelDown(userAddress);
    }

    /**
     * Функция для рассылки токенов Gbr пользователям
     * @dev Вызывается два раза в месяц для рассылки токенов
     */
    function distributeGbrTokens() public {
        // Определяем количество токенов для каждого уровня
        uint256[] memory tokenAmounts = [10_000_000, 100_000_000, 1_000_000_000, 10_000_000_000];

        // Проходим по всем пользователям и отправляем токены
        for (uint256 i = 1; i <= maxLevel; i++) {
            for (address userAddress  getLevelUsers(i)) {
                uint256 amount = tokenAmounts[i - 1];
                GbrToken.transfer(userAddress, amount);
            }
        }
    }

    /**
     * Функция для получения пользователей определенного уровня
     * @param level Уровень пользователей
     * @return Массив адресов пользователей
     */
    function getLevelUsers(uint32 level) public view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[users[i].userAddress].level == level) {
                count++;
            }
        }

        address[] memory levelUsers = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < users.length; i++) {
            if (users[users[i].userAddress].level == level) {
                levelUsers[index] = users[i].userAddress;
                index++;
            }
        }

        return levelUsers;
    }

    /**
     * Функция для вывода Gbr токенов с контракта
     * @param amount Количество Gbr токенов для вывода
     * @dev Только члены Gybernaty могут выводить Gbr токены
     */
    function withdrawGbrTokens(uint256 amount) public onlyGybernaty {
        // Выводим Gbr токены на адрес вызывающего
        GbrToken.transfer(msg.sender, amount);
    }

    /**
     * Функция для приема Gbr токенов
     * @dev Отклоняет любые другие токены, кроме Gbr токенов
     */
    receive() external payable {
        // Проверяем, является ли отправитель адресом контракта Gbr токенов
        if (msg.sender != address(GbrToken)) {
            revert(); // Отклонить любые другие токены
        }
    }
}