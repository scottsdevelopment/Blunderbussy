
-- Define the Blunderbuss class
local Blunderbuss = {
    RED = {1, 0, 0, 1},
    GREEN = {0, 1, 0, 1},
    BLACK = {0, 0, 0, 1},
    blunderbussItemID = 4369,
    lowestPrice = nil,
    seller = nil,
    lastAuctionSellItemID = nil
}

-- Initialize the main frame
function Blunderbuss:CreateMainFrame()
    self.mainFrame = CreateFrame("Frame", "BlunderbussMainFrame", WorldFrame, "BackdropTemplate")
    self.mainFrame:SetSize(300, 300)
    self.mainFrame:SetPoint("RIGHT")
    self.mainFrame:EnableMouse(true)

    local background = self.mainFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(self.mainFrame)
    background:SetColorTexture(unpack(self.BLACK))

    self.statusText = self.mainFrame:CreateFontString(nil, "OVERLAY")
    self.statusText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    self.statusText:SetPoint("CENTER")
    self.statusText:SetText("Status: Ready to undercut")

    self.auctionFrame = CreateFrame("Frame")
    self.auctionFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self.auctionFrame:SetScript("OnEvent", function() self:ProcessAuctionData() end)

    self.button = CreateFrame("Button", "BlunderbussButton", self.mainFrame, "GameMenuButtonTemplate")
    self.button:SetPoint("BOTTOM", self.mainFrame, "BOTTOM", 0, 10)
    self.button:SetSize(100, 20)
    self.button:SetText("")
    self.button:SetNormalFontObject("GameFontNormal")
    self.button:SetScript("OnClick", function() self:OnButtonClick() end)

    UIParent:Hide()
    self.mainFrame:Show()
    self.auctionFrame:Show()
end

-- Update the status text
function Blunderbuss:UpdateStatus(newStatus)
    self.statusText:SetText("Status: " .. newStatus)
end

function Blunderbuss:SearchForItem(itemName)
    self.lowestPrice = nil
    self.seller = nil
    self.lastAuctionSellItemID = nil
    self:UpdateStatus("Searching for " .. itemName)
    QueryAuctionItems(itemName)
end

function Blunderbuss:Craft(tradeSkill, itemName)
    local spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, interrupt = UnitCastingInfo("player")
    if not isTradeSkill then
        CastSpellByName(tradeSkill)
    
        for skillIndex = 1, GetNumTradeSkills() do
            local skillName, skillType, numAvailable, isExpanded, altVerb, numSkillUps = GetTradeSkillInfo(skillIndex)
            if numAvailable > 0 and skillName == itemName then 
                CloseTradeSkill() 
                DoTradeSkill(skillIndex)
                self:UpdateStatus("Crafting "..itemName)
                return 1
            end 
        end
    else
        self:UpdateStatus("Currently crafting something else.")
        return -1
    end
    return 0
end

function Blunderbuss:CountBagItem(searchItemID)
    local totalCount = 0

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID == searchItemID then
               
                local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
                local stackCount = containerInfo and containerInfo.stackCount or 0

                totalCount = totalCount + (stackCount or 0)
            end
        end
    end

    return totalCount
end

function Blunderbuss:BuyVendorItem(itemID, quantityToBuy)
    local totalBought = 0
    local owned = self:CountBagItem(itemID)
    if owned >= quantityToBuy then return end

    if MerchantFrame:IsShown() then
        for i = 1, GetMerchantNumItems() do
            local name, _, price, quantity, numAvailable, isPurchasable = GetMerchantItemInfo(i)
            local link = GetMerchantItemLink(i)
            local _, _, _, _, merchantItemID, _, _, _, _, _, _, _, _, _ = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
            -- local name, _, _, _, _, _, _, _, _, _, _, merchantItemID = GetItemInfo(link)
            local maxStack = GetMerchantItemMaxStack(i)
            merchantItemID = tonumber(merchantItemID)
            

            if itemID == merchantItemID then
                local owned = self:CountBagItem(itemID)
                quantityToBuy = quantityToBuy - owned
                local stackCount = math.min(math.min(maxStack, quantity), quantityToBuy)
                while quantityToBuy > 0 do
                    BuyMerchantItem(i, stackCount)
                    totalBought = totalBought + stackCount
                    quantityToBuy = quantityToBuy - stackCount
                end

                self:UpdateStatus("Bought " .. totalBought .. " " .. link)
                return
            end
        end

        if totalBought < quantityToBuy then
            self:UpdateStatus("Couldn't buy the required amount of " .. itemID)
        end
    else
        self:UpdateStatus("Vendor window is not open.")
    end
end

function Blunderbuss:IsAuctionHouseOpen()
    return AuctionFrame and AuctionFrame:IsShown()
end

function Blunderbuss:IsVendorOpen()
    return MerchantFrame:IsShown()
end

function Blunderbuss:IsCraftingArea()
    -- Return crafting area check logic
    return true
end

function Blunderbuss:IterateAllFrames()
    local frameList = {UIParent:GetChildren()}
    for i, frame in ipairs(frameList) do
        if frame ~= self and frame and frame.GetName then
            frame:Hide()
        end
    end
end

function Blunderbuss:HideUIFrames(exceptFrame)
    for _, frameName in ipairs(self.framesToHide) do
        local frame = _G[frameName]
        if frame and frame ~= exceptFrame then
            frame:Hide()
        end
    end
end

function Blunderbuss:IsMailboxOpen()
    return GetInboxNumItems() > 0 and MailFrame and MailFrame:IsVisible()
end

function Blunderbuss:OpenFirstMail()
    if not self:IsMailboxOpen() then
        return
    end

    if GetInboxNumItems() > 0 then
        -- Open the first mail
        AutoLootMailItem(1)
    else
        self:UpdateStatus("Mail is empty")
    end
end

function Blunderbuss:OnButtonClick2()
    if self.lowestPrice and self.lastAuctionSellItemID == self.blunderbussItemID then
        PostAuction(self.lowestPrice - 1, self.lowestPrice - 1, 1, 1, 1)
        self:UpdateStatus("Posting auction")
    end
    self.lowestPrice = nil
    self.seller = nil
    self.lastAuctionSellItemID = nil
    self.button:SetScript("OnClick", function() self:OnButtonClick() end)
end

function Blunderbuss:OnButtonClick()
    if self:IsMailboxOpen() then
        self:UpdateStatus("Opening mail")
        self:OpenFirstMail()
    elseif self:IsAuctionHouseOpen() then
        self:UpdateStatus("Auction house detected")
        self:SearchForItem("Deadly Blunderbuss")
    elseif self:IsVendorOpen() then
        self:BuyVendorItem(4399, 10)
        self:BuyVendorItem(2880, 20)
    elseif self:IsCraftingArea() then
        if self:Craft("Engineering", "Deadly Blunderbuss") == 1 then return end
        if self:CountBagItem(4361) < 20 and self:Craft("Engineering", "Copper Tube") == 1 then return end
        if self:CountBagItem(4359) < 40 and self:Craft("Engineering", "Handful of Copper Bolts") == 1 then return end
        self:UpdateStatus("Ready to sell on Auction House")
    end
end

function Blunderbuss:PrepareAuctionForBlunderbuss(buyoutPrice)
    local cursorType, cursorItemID, itemLink = GetCursorInfo()


    if cursorType == "item" and cursorItemID == self.blunderbussItemID then
        ClickAuctionSellItemButton()
        local _, _, _, _, _, _, _, _, _, auctionSellItemID = GetAuctionSellItemInfo()
        self.lastAuctionSellItemID = auctionSellItemID    
        self.button:SetScript("OnClick", function() self:OnButtonClick2() end)
        return
    end

    -- Find the Deadly Blunderbuss in the player's bags
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if (cursorType ~= "item" or cursorItemID ~= self.blunderbussItemID) and (itemID and itemID == self.blunderbussItemID) then
                C_Container.PickupContainerItem(bag, slot)
                self:UpdateStatus("Picking up item")
                
                return
            end
        end
    end

    self:UpdateStatus("Deadly Blunderbuss not found in bags.")
end


function Blunderbuss:ProcessAuctionData()
    self.lowestPrice = nil
    self.seller = nil

    local _, numItems = GetNumAuctionItems("list")

    for i = 1, numItems do
        local name, texture, count, quality, canUse, level, levelColHeader, minBid,
    minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
    ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)

        -- if itemId and itemId ~= blunderbussItemID then
        --     return
        -- end
        -- print(name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo)
        if itemId == self.blunderbussItemID and owner and buyoutPrice ~= 0 and (not self.lowestPrice or buyoutPrice <  self.lowestPrice) then
            self.lowestPrice = buyoutPrice
            self.seller = owner
        end
    end

    if self.lowestPrice then
        self:UpdateStatus("Lowest price: " .. GetCoinTextureString(self.lowestPrice) .. " by " .. self.seller)
    else
        self:UpdateStatus("No items found.")
        return
    end

    if self.lowestPrice and self.seller ~= UnitName("player") then
        self:UpdateStatus("Under cut detected")
        self:PrepareAuctionForBlunderbuss(self.lowestPrice - 1)
    end
end

-- Usage example
local blunderbussInstance = setmetatable({}, {__index = Blunderbuss})
blunderbussInstance:CreateMainFrame()
