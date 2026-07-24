-- Fox Mill Woods — Azure SQL schema (spec §5). Idempotent; safe to re-run.
-- Apply after `azd up` provisions the server, e.g.:
--   sqlcmd -S <server>.database.windows.net -d foxmillwoods -G -i infra/sql/schema.sql
-- (-G = Entra auth). Roles/field-tiers are enforced in the API, not here.

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- ---------- Households ----------
IF OBJECT_ID('dbo.Households') IS NULL
CREATE TABLE dbo.Households (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Households PRIMARY KEY DEFAULT NEWID(),
    address     NVARCHAR(300)    NOT NULL,          -- residency verification; board-visible only
    createdAt   DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ---------- Users ----------
IF OBJECT_ID('dbo.Users') IS NULL
CREATE TABLE dbo.Users (
    id                      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Users PRIMARY KEY DEFAULT NEWID(),
    name                    NVARCHAR(200)    NOT NULL,
    email                   NVARCHAR(320)    NOT NULL,
    phone                   NVARCHAR(40)     NULL,
    role                    VARCHAR(20)      NOT NULL DEFAULT 'resident'
                              CONSTRAINT CK_Users_role CHECK (role IN ('resident','eventCoordinator','boardMember')),
    status                  VARCHAR(20)      NOT NULL DEFAULT 'pending'
                              CONSTRAINT CK_Users_status CHECK (status IN ('pending','active')),
    membershipStatus        VARCHAR(20)      NOT NULL DEFAULT 'unpaid'
                              CONSTRAINT CK_Users_membership CHECK (membershipStatus IN ('paid','unpaid','pending','processing')),
    duesPaidThrough         DATE             NULL,
    householdId             UNIQUEIDENTIFIER NULL CONSTRAINT FK_Users_Household REFERENCES dbo.Households(id),
    authProviderSub         NVARCHAR(200)    NOT NULL,   -- Entra 'sub' claim
    emailVisibleToNeighbors BIT              NOT NULL DEFAULT 1,
    createdAt               DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Users_authProviderSub')
    CREATE UNIQUE INDEX UX_Users_authProviderSub ON dbo.Users(authProviderSub);

-- ---------- FacilityHours (Pool & Tennis) ----------
IF OBJECT_ID('dbo.FacilityHours') IS NULL
CREATE TABLE dbo.FacilityHours (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_FacilityHours PRIMARY KEY DEFAULT NEWID(),
    facility    VARCHAR(20)      NOT NULL CHECK (facility IN ('pool','tennis')),
    dayRange    NVARCHAR(40)     NOT NULL,        -- e.g. 'Mon–Fri'
    opensAt     TIME             NULL,
    closesAt    TIME             NULL,
    note        NVARCHAR(120)    NULL             -- e.g. 'Adult swim'
);

-- ---------- Events ----------
IF OBJECT_ID('dbo.Events') IS NULL
CREATE TABLE dbo.Events (
    id            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Events PRIMARY KEY DEFAULT NEWID(),
    title         NVARCHAR(200)    NOT NULL,
    startAt       DATETIME2        NOT NULL,
    endAt         DATETIME2        NULL,
    location      NVARCHAR(200)    NULL,
    audience      NVARCHAR(60)     NULL,          -- All residents / Adults / Family / Household
    description   NVARCHAR(2000)   NULL,
    ticketingType VARCHAR(10)      NOT NULL DEFAULT 'free' CHECK (ticketingType IN ('free','paid')),
    budgetTarget  DECIMAL(10,2)    NULL,
    visibility    VARCHAR(20)      NOT NULL DEFAULT 'all' CHECK (visibility IN ('all','invite')),
    status        VARCHAR(20)      NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
    createdBy     UNIQUEIDENTIFIER NULL CONSTRAINT FK_Events_CreatedBy REFERENCES dbo.Users(id),
    createdAt     DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Coordinators for an event (many-to-many).
IF OBJECT_ID('dbo.EventCoordinators') IS NULL
CREATE TABLE dbo.EventCoordinators (
    eventId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_EvCoord_Event REFERENCES dbo.Events(id) ON DELETE CASCADE,
    userId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_EvCoord_User  REFERENCES dbo.Users(id),
    CONSTRAINT PK_EventCoordinators PRIMARY KEY (eventId, userId)
);

-- ---------- EventItems (an event has 0..n paid items) ----------
IF OBJECT_ID('dbo.EventItems') IS NULL
CREATE TABLE dbo.EventItems (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_EventItems PRIMARY KEY DEFAULT NEWID(),
    eventId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_EventItems_Event REFERENCES dbo.Events(id) ON DELETE CASCADE,
    name        NVARCHAR(120)    NOT NULL,
    price       DECIMAL(10,2)    NOT NULL,
    itemLimit   INT              NULL,            -- nullable = unlimited
    sortOrder   INT              NOT NULL DEFAULT 0,
    isOptional  BIT              NOT NULL DEFAULT 0
);

-- ---------- Orders / OrderLines ("who paid for what") ----------
IF OBJECT_ID('dbo.Orders') IS NULL
CREATE TABLE dbo.Orders (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Orders PRIMARY KEY DEFAULT NEWID(),
    eventId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_Orders_Event REFERENCES dbo.Events(id),
    userId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_Orders_User  REFERENCES dbo.Users(id),
    total       DECIMAL(10,2)    NOT NULL,
    paymentId   UNIQUEIDENTIFIER NULL,
    status      VARCHAR(20)      NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','refunded','canceled')),
    createdAt   DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);
IF OBJECT_ID('dbo.OrderLines') IS NULL
CREATE TABLE dbo.OrderLines (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_OrderLines PRIMARY KEY DEFAULT NEWID(),
    orderId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_OrderLines_Order REFERENCES dbo.Orders(id) ON DELETE CASCADE,
    eventItemId UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_OrderLines_Item  REFERENCES dbo.EventItems(id),
    quantity    INT              NOT NULL,
    unitPrice   DECIMAL(10,2)    NOT NULL,
    lineTotal   DECIMAL(10,2)    NOT NULL
);

-- ---------- Dues (annual; ACH is async) ----------
IF OBJECT_ID('dbo.DuesPeriods') IS NULL
CREATE TABLE dbo.DuesPeriods (
    id            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DuesPeriods PRIMARY KEY DEFAULT NEWID(),
    year          INT              NOT NULL,
    amount        DECIMAL(10,2)    NOT NULL,
    dueDate       DATE             NULL,
    coverageStart DATE             NULL,
    coverageEnd   DATE             NULL,
    description   NVARCHAR(200)    NULL,
    isActive      BIT              NOT NULL DEFAULT 1     -- one active period at a time
);
IF OBJECT_ID('dbo.DuesPayments') IS NULL
CREATE TABLE dbo.DuesPayments (
    id           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DuesPayments PRIMARY KEY DEFAULT NEWID(),
    duesPeriodId UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DuesPayments_Period REFERENCES dbo.DuesPeriods(id),
    userId       UNIQUEIDENTIFIER NULL CONSTRAINT FK_DuesPayments_User REFERENCES dbo.Users(id),
    householdId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_DuesPayments_Household REFERENCES dbo.Households(id),
    amount       DECIMAL(10,2)    NOT NULL,
    paymentId    NVARCHAR(120)    NULL,            -- Stripe PaymentIntent id
    method       VARCHAR(10)      NOT NULL CHECK (method IN ('ach','card','cash','check')),
    status       VARCHAR(20)      NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','succeeded','failed')),
    paidAt       DATETIME2        NULL
);

-- ---------- Pavilion ----------
IF OBJECT_ID('dbo.PavilionBookings') IS NULL
CREATE TABLE dbo.PavilionBookings (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_PavilionBookings PRIMARY KEY DEFAULT NEWID(),
    [date]      DATE             NOT NULL,
    block       NVARCHAR(40)     NULL,
    userId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_Pavilion_User REFERENCES dbo.Users(id),
    fee         DECIMAL(10,2)    NOT NULL,
    paymentId   UNIQUEIDENTIFIER NULL,
    status      VARCHAR(20)      NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','booked','canceled'))
);

-- ---------- Payments in (multi-source) ----------
IF OBJECT_ID('dbo.Payments') IS NULL
CREATE TABLE dbo.Payments (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Payments PRIMARY KEY DEFAULT NEWID(),
    orderId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_Payments_Order REFERENCES dbo.Orders(id),
    bookingId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_Payments_Booking REFERENCES dbo.PavilionBookings(id),
    userId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_Payments_User REFERENCES dbo.Users(id),
    amount      DECIMAL(10,2)    NOT NULL,
    source      VARCHAR(10)      NOT NULL CHECK (source IN ('card','venmo','cash','check','ach')),
    stripeRef   NVARCHAR(120)    NULL,
    loggedBy    UNIQUEIDENTIFIER NULL CONSTRAINT FK_Payments_LoggedBy REFERENCES dbo.Users(id),
    [timestamp] DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ---------- Expenses (out) ----------
IF OBJECT_ID('dbo.Expenses') IS NULL
CREATE TABLE dbo.Expenses (
    id               UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Expenses PRIMARY KEY DEFAULT NEWID(),
    eventId          UNIQUEIDENTIFIER NULL CONSTRAINT FK_Expenses_Event REFERENCES dbo.Events(id),
    paidByUserId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_Expenses_PaidBy REFERENCES dbo.Users(id),
    merchant         NVARCHAR(200)    NULL,
    [date]           DATE             NULL,
    amount           DECIMAL(10,2)    NOT NULL,
    tax              DECIMAL(10,2)    NULL,
    category         NVARCHAR(60)     NULL,
    receiptBlobUrl   NVARCHAR(400)    NULL,
    reimbursedStatus VARCHAR(20)      NOT NULL DEFAULT 'owed' CHECK (reimbursedStatus IN ('owed','reimbursed'))
);

-- ---------- AuditLog (dues/role/financial changes) ----------
IF OBJECT_ID('dbo.AuditLog') IS NULL
CREATE TABLE dbo.AuditLog (
    id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_AuditLog PRIMARY KEY DEFAULT NEWID(),
    actorId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_AuditLog_Actor REFERENCES dbo.Users(id),
    action      NVARCHAR(80)     NOT NULL,
    target      NVARCHAR(200)    NULL,
    detail      NVARCHAR(1000)   NULL,
    [timestamp] DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
