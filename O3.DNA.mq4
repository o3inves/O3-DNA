#property copyright "O3 Corp."
#property version   "1.09"
#property strict

double LastDayHigh, 
         LastDayLow,
         LowerPrice,
         HigherPrice,
         OpenPrice,
         lotsi,
         lotsp,
         LotsToClose,
         LastBalance = 0, 
         LastLots;
 int total,BuyCanTrade,SellCanTrade,hour,minute,time;
 
 extern double risk = 7; //Acc risk:
 extern int TakeProfit = 80; //TakeProfit in Points:
 extern int stoploss = 20; //StopLoss in Points:
 extern int pieces = 9; //Pieces to close: 
 extern int Gap = 0; //Initial order Gap;
 extern int DoubleBrake = 1; // Enable high/low brakout on the same day
 extern int FTpPieces = 1; // First TP pieces to close:
 extern int AllowLotRed = 0; // Allow Lot value reduction:
 extern double MaxLots = 100; //Broker Max Lat
 extern int DayTime = 0;
 extern int Debug = 0;
 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   total = OrdersTotal();
   LotsStartUp();
   
   BuyCanTrade =  1;  
   SellCanTrade = 1;  
   
   LastDayHigh = 0;
   LastDayLow  = 0;
   
   ObjectCreate("HlineBuy",OBJ_HLINE,0,Time[0],LastDayHigh,0,0,0,0);
   ObjectCreate("HlineSell",OBJ_HLINE,0,Time[0],LastDayLow,0,0,0,0);
   
   GetLastTops();
   
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   if( (TimeHour(TimeCurrent()) == DayTime) && (TimeMinute(TimeCurrent()) <= 2) )
     {
         GetLastTops();
         BuyCanTrade  = 1;
         SellCanTrade = 1;
     }
   
   switch(total)
     {
      case  0:
        if( (Ask > (LastDayHigh+Gap*Point)) && BuyCanTrade == 1)
         {
            OrderBuy();
         }
        if( (Bid < (LastDayLow-Gap*Point)) && SellCanTrade == 1)
         {
            OrderSell();
         }   
        break;
       case  1:
         if(OrderSelect(0,SELECT_BY_POS,MODE_TRADES) == true)
         {
            if( OrderType() == OP_BUY )
              {
                  OrderBuyClose();
              }
            else if( OrderType() == OP_SELL)
              {
                  OrderSellClose();
              }
            
         }
         
        break;
      default:
        break;
    
      }
}
//+------------------------------------------------------------------+

void  GetLastTops(){

   LastDayHigh = High[iHighest(Symbol(),PERIOD_M15,MODE_HIGH,96,0)];
   LastDayLow  = Low[iLowest(Symbol(),PERIOD_M15,MODE_LOW,96,0)]; 
   
   ObjectSetDouble(0,"HlineBuy",OBJPROP_PRICE,LastDayHigh);
   ObjectSetDouble(0,"HlineSell",OBJPROP_PRICE,LastDayLow);
   
   if(Debug == 1)
     {
      Print("Day High/Low Seted: High "+LastDayHigh+" | Low "+LastDayLow+" | Time: "+TimeCurrent());
     }

}
//+------------------------------------------------------------------+
//| Order BUY/CLOSE function                                  
//+------------------------------------------------------------------+

void OrderBuy(){
   
   OrderSend(Symbol(),OP_BUY,lotsi,Ask,5,0,0,NULL,100,0,clrBlue); 
   OpenPrice = Ask;
   
   LotsToClose = NormalizeDouble((lotsi/pieces),2);     
   if(LotsToClose < 0.01)
     {
         LotsToClose = 0.01; //Prevent lots lower than the min lot allowed; 
     }
   
   switch(DoubleBrake)
     {
      case  0:
         BuyCanTrade = 0;  
         SellCanTrade = 0;
        break;
      case  1:
         BuyCanTrade = 0;  
        break;
      default:
        break;
     }
     
   LastBalance = AccountBalance();
   total = OrdersTotal(); 
     
}

void OrderBuyClose(){
   if( (Bid > (OpenPrice+TakeProfit*Point)) )
     {

             if(LotsToClose > OrderLots())
               {
                  LotsToClose = OrderLots();
               } 
         
             OrderClose(OrderTicket(),LotsToClose,Bid,5,clrBlueViolet); 
             OpenPrice = Bid;    
         
             total = OrdersTotal();
             AccManager(); 

     }
     
    if( (Bid < (OpenPrice-stoploss*Point)) )
      {
         OrderClose(OrderTicket(),OrderLots(),Bid,5,clrBlueViolet); 
         total = OrdersTotal();

         AccManager();
      }
}

//+------------------------------------------------------------------+
//| Order SELL function                                  
//+------------------------------------------------------------------+

void OrderSell(){
   OrderSend(Symbol(),OP_SELL,lotsi,Bid,5,0,0,NULL,200,0,clrRed);
  
   OpenPrice = Bid;
  
   LotsToClose = NormalizeDouble((lotsi/pieces),2);    
   if(LotsToClose < 0.01)
     {
         LotsToClose = 0.01; //Prevent lots lower than the min lot allowed; 
     }
  
   switch(DoubleBrake)
     {
      case  0:
         BuyCanTrade = 0;  
         SellCanTrade = 0;
        break;
      case  1:
         SellCanTrade = 0;  
        break;
      default:
        break;
     }
   
   LastBalance = AccountBalance();
   total = OrdersTotal();
}

void OrderSellClose(){
   if( Ask < (OpenPrice-TakeProfit*Point) )
     {
        
            if(LotsToClose > OrderLots())
               {
                  LotsToClose = OrderLots();
               }        
            OrderClose(OrderTicket(),LotsToClose,Ask,5,clrBlueViolet); 
            OpenPrice = Ask;
         
            total = OrdersTotal();
            AccManager();

     }
     
   if( (Ask > (OpenPrice+stoploss*Point))  )
     {
         OrderClose(OrderTicket(),OrderLots(),Ask,5,clrBlueViolet); 
         
         total = OrdersTotal();

         AccManager();
         
     }
}
//+------------------------------------------------------------------+
void AccManager(){
   
   lotsp=NormalizeDouble((AccountBalance()*risk/10000),2);
   if (lotsp<0.01) lotsp=0.01;   
   if (lotsp>MaxLots) lotsp=MaxLots;   
   
   if( (AllowLotRed == 0) )
     {
         if(lotsp < lotsi)
           {
               Print("Lot reduction disabled. Lot value will be the same of the previous trade.");   
           }
         else
           {
               lotsi=lotsp ;          
           }
     }
   else
     {
         lotsi=lotsp;
     }
   

}

void LotsStartUp(){

         lotsi=NormalizeDouble((AccountBalance()*risk/10000),2);
         if (lotsi<0.01) lotsi=0.01;   
         if (lotsi>MaxLots) lotsi=MaxLots;   

}