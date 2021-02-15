 
   CREATE TABLE XXBCM_CONTACT
   (
    CONTACT_ID          NUMBER GENERATED ALWAYS AS IDENTITY,
	SUPP_CONTACT_NAME 	VARCHAR2(2000), 
	SUPP_ADDRESS 		VARCHAR2(2000), 
	SUPP_CONTACT_NUMBER VARCHAR2(2000), 
	SUPP_EMAIL 			VARCHAR2(2000),
    CREATION_TIMESTAMP  TIMESTAMP,
    CREATION_USER       VARCHAR2(30),
    CONSTRAINT XXBCM_CONTACT_PK PRIMARY KEY (CONTACT_ID)
   ) ;
 
  CREATE TABLE XXBCM_SUPPLIER
   (	
    SUPPLIER_ID         NUMBER GENERATED ALWAYS AS IDENTITY,
    SUPPLIER_NAME 		VARCHAR2(2000),
    CONTACT_ID          NUMERIC(10) NOT NULL,
    CREATION_TIMESTAMP  TIMESTAMP,
    CREATION_USER       VARCHAR2(30),
    CONSTRAINT XXBCM_SUPPLIER_PK PRIMARY KEY (SUPPLIER_ID),
    CONSTRAINT FK_CONTACT_ID FOREIGN KEY (CONTACT_ID) REFERENCES XXBCM_CONTACT(CONTACT_ID)
   ) ;
   

  CREATE TABLE XXBCM_ORDER
   (	
    ORDER_ID            NUMBER GENERATED ALWAYS AS IDENTITY,
    SUPPLIER_ID         NUMERIC(10) NOT NULL,    
    ORDER_REF 			VARCHAR2(2000), 
	ORDER_DATE 			DATE, 
	ORDER_TOTAL_AMOUNT 	NUMBER, 
	ORDER_DESCRIPTION 	VARCHAR2(2000), 
	ORDER_STATUS 		VARCHAR2(2000), 
    CREATION_TIMESTAMP  TIMESTAMP,
    CREATION_USER       VARCHAR2(30),
    CONSTRAINT XXBCM_ORDER_PK PRIMARY KEY (ORDER_ID),
    CONSTRAINT FK_SUPPLIER_ID FOREIGN KEY (SUPPLIER_ID) REFERENCES XXBCM_SUPPLIER(SUPPLIER_ID)
   ) ;


  CREATE TABLE XXBCM_INVOICE 
   (	
    INVOICE_ID          NUMBER GENERATED ALWAYS AS IDENTITY,
    ORDER_ID            NUMERIC(10) NOT NULL,
    ORDER_REF 			VARCHAR2(2000), 
    ORDER_DESCRIPTION 	VARCHAR2(2000), 
	ORDER_STATUS 		VARCHAR2(2000), 
    ORDER_LINE_AMOUNT 	NUMBER,
	INVOICE_REFERENCE 	VARCHAR2(2000), 
	INVOICE_DATE 		DATE, 
	INVOICE_STATUS 		VARCHAR2(2000), 
	INVOICE_HOLD_REASON VARCHAR2(2000), 
	INVOICE_AMOUNT 		NUMBER, 
	INVOICE_DESCRIPTION VARCHAR2(2000),
    CREATION_TIMESTAMP  TIMESTAMP,
    CREATION_USER       VARCHAR2(30),
    CONSTRAINT XXBCM_INVOICE_PK PRIMARY KEY (INVOICE_ID),
    CONSTRAINT FK_ORDER_ID FOREIGN KEY (ORDER_ID) REFERENCES XXBCM_ORDER(ORDER_ID)
   ) ;

/


--- PACKAGE ---
CREATE OR REPLACE PACKAGE BMC_IMPORT IS
  FUNCTION Format_written_amount(VNUMBER IN VARCHAR2) RETURN NUMBER;
  FUNCTION Format_written_call_num(VNUMBER IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION Format_date(VDATE IN VARCHAR2) RETURN DATE;
 
  FUNCTION Invoice_Total_Amount(NORDER_ID IN NUMBER) RETURN NUMBER;
  FUNCTION Order_Action(NORDER_ID IN NUMBER) RETURN VARCHAR2;
  FUNCTION Nth_highest_Amount(N_th IN NUMBER) RETURN NUMBER;
  FUNCTION Invoice_List(NORDER_ID IN NUMBER) RETURN VARCHAR2;
  
  PROCEDURE P3_IMPORT;
 
END;
/


CREATE OR REPLACE PACKAGE BODY BMC_IMPORT IS
    --- correction on typing error and conversion ---
    FUNCTION Format_written_amount(VNUMBER IN VARCHAR2)
    RETURN NUMBER IS 
       n_result NUMBER := 0;
       v_result VARCHAR2(2000);
    BEGIN
      v_result := NVL(VNUMBER,'0');
      v_result := REPLACE( v_result, 'o', '0' );
      v_result := REPLACE( v_result, 'O', '0' );
      v_result := REPLACE( v_result, 'i', '1' );
      v_result := REPLACE( v_result, 'I', '1' );
      v_result := REPLACE( v_result, 'l', '1' );
      v_result := REPLACE( v_result, 's', '5' );
      v_result := REPLACE( v_result, 'S', '5' );
      v_result := REPLACE( v_result, ' ', '' );
      v_result := REPLACE( v_result, ',', '' );
      n_result := to_number(v_result);
      RETURN n_result;
      
      EXCEPTION
      WHEN OTHERS THEN
      RETURN -1;
--By PM
    END;
    
    FUNCTION Format_written_call_num(VNUMBER IN VARCHAR2)
    RETURN VARCHAR2 IS 
       v_result VARCHAR2(2000);
    BEGIN
      v_result := NVL(VNUMBER,'');
      v_result := REPLACE( v_result, 'o', '0' );
      v_result := REPLACE( v_result, 'O', '0' );
      v_result := REPLACE( v_result, 'i', '1' );
      v_result := REPLACE( v_result, 'I', '1' );
      v_result := REPLACE( v_result, 'l', '1' );
      v_result := REPLACE( v_result, 's', '5' );
      v_result := REPLACE( v_result, 'S', '5' );
      v_result := REPLACE( v_result, ' ', '' );
      RETURN v_result;
      
      EXCEPTION
      WHEN OTHERS THEN
      RETURN '0';
--By PM
    END;
    
    FUNCTION Format_date(VDATE IN VARCHAR2)
    RETURN DATE IS 
       v_result DATE;
    BEGIN
      if Ascii(SUBSTR( nvl(VDATE,'01-JAN-1900'),4,1))>57 then
        v_result := to_date(NVL(VDATE,'01-JAN-1900'));
      else 
        v_result := to_date(NVL(VDATE,'01-JAN-1900'),'DD-MM-YYYY');
      end if;
      RETURN v_result;

      EXCEPTION
      WHEN OTHERS THEN
      RETURN to_date('01-JAN-1950');
--By PM
    END;
      
    FUNCTION Invoice_Total_Amount(NORDER_ID IN NUMBER)
    RETURN NUMBER IS 
       n_result NUMBER;
    BEGIN
      select sum(xi.invoice_amount) into n_result 
      from xxbcm_invoice xi 
      where xi.order_id=NORDER_ID;
      RETURN n_result;
      
      EXCEPTION
      WHEN OTHERS THEN
      RETURN -1;
--By PM
    END;
    
    
    FUNCTION Order_Action(NORDER_ID IN NUMBER)
    RETURN VARCHAR2 IS 
       v_result VARCHAR2(20);
    BEGIN
      select max(nvl(xi.invoice_status,'To verify')) into v_result
      from xxbcm_invoice xi 
      where xi.order_id=NORDER_ID; 
      v_result := CASE v_result 
                    when 'Paid' then 'OK'
                    when 'Pending' then 'To follow up'
                    ELSE 'To verify'
                  END;
      RETURN v_result;
      
      EXCEPTION
      WHEN OTHERS THEN
      RETURN 'ERROR';
--By PM
    END;
 
    FUNCTION Nth_highest_Amount(N_th IN NUMBER) 
    RETURN NUMBER IS 
       n_result NUMBER;
    BEGIN

      SELECT sxo.ORDER_ID into n_result
      FROM 
      (
      select xo.ORDER_ID, xo.order_total_amount,row_number() over (order by xo.order_total_amount desc) as rn 
      FROM  xxbcm_order xo
      order by 2 desc ) sxo 
      where sxo.rn =N_th;
      RETURN n_result;

      EXCEPTION
      WHEN OTHERS THEN
      RETURN -1;
--By PM
    END;
    
    FUNCTION Invoice_List(NORDER_ID IN NUMBER) 
    RETURN VARCHAR2 IS 
       v_result VARCHAR2(2000);
    BEGIN
      SELECT LISTAGG(xi.invoice_reference, ', ') WITHIN GROUP (ORDER BY invoice_reference) Invoice_Listing INTO v_result
      FROM xxbcm_invoice xi 
      where xi.invoice_reference is not null and xi.order_id=NORDER_ID; 
      RETURN v_result;
      
      EXCEPTION
      WHEN OTHERS THEN
      RETURN 'ERROR';
    END; 
 
 
 --a migration process that will extract information from table "XXBCM_ORDER_MGT"
    PROCEDURE P3_IMPORT IS
    BEGIN

        --XXBCM_CONTACT
        INSERT INTO XXBCM_CONTACT (SUPP_CONTACT_NAME,SUPP_ADDRESS,SUPP_CONTACT_NUMBER,SUPP_EMAIL,CREATION_TIMESTAMP,CREATION_USER)
        SELECT distinct XOM.SUPP_CONTACT_NAME,XOM.SUPP_ADDRESS,Format_written_call_num(XOM.SUPP_CONTACT_NUMBER),XOM.SUPP_EMAIL,SYSDATE,USER 
        FROM XXBCM_ORDER_MGT XOM
        WHERE NOT EXISTS (SELECT 1 FROM XXBCM_CONTACT DEST WHERE DEST.SUPP_CONTACT_NAME=XOM.SUPP_CONTACT_NAME AND DEST.SUPP_EMAIL=XOM.SUPP_EMAIL);
    
        --XXBCM_SUPPLIER
        INSERT INTO XXBCM_SUPPLIER (SUPPLIER_NAME,CONTACT_ID,CREATION_TIMESTAMP,CREATION_USER)
        SELECT distinct XOM.SUPPLIER_NAME,ORG.CONTACT_ID,SYSDATE,USER 
        FROM  XXBCM_ORDER_MGT XOM 
        INNER JOIN  XXBCM_CONTACT ORG on ORG.SUPP_CONTACT_NAME=XOM.SUPP_CONTACT_NAME AND ORG.SUPP_EMAIL=XOM.SUPP_EMAIL 
        WHERE NOT EXISTS (SELECT 1 FROM XXBCM_SUPPLIER DEST WHERE DEST.SUPPLIER_NAME=XOM.SUPPLIER_NAME);
    
        --XXBCM_ORDER
        INSERT INTO  XXBCM_ORDER (SUPPLIER_ID,ORDER_REF,ORDER_DATE,ORDER_TOTAL_AMOUNT,ORDER_DESCRIPTION,ORDER_STATUS,CREATION_TIMESTAMP,CREATION_USER)
        SELECT distinct ORG.SUPPLIER_ID,XOM.ORDER_REF,Format_date(XOM.ORDER_DATE),Format_written_amount(XOM.ORDER_TOTAL_AMOUNT),XOM.ORDER_DESCRIPTION,XOM.ORDER_STATUS,SYSDATE,USER 
        FROM XXBCM_ORDER_MGT XOM
        INNER JOIN XXBCM_SUPPLIER ORG ON ORG.SUPPLIER_NAME=XOM.SUPPLIER_NAME
        WHERE XOM.ORDER_REF not like '%-%' AND NOT EXISTS (SELECT 1 FROM XXBCM_ORDER DEST WHERE DEST.ORDER_REF=XOM.ORDER_REF ) order by XOM.ORDER_REF;
    
        --XXBCM_INVOICE
        INSERT INTO  XXBCM_INVOICE (ORDER_ID,ORDER_REF,ORDER_DESCRIPTION,ORDER_STATUS,ORDER_LINE_AMOUNT,INVOICE_REFERENCE,INVOICE_DATE,INVOICE_STATUS,INVOICE_HOLD_REASON,INVOICE_AMOUNT,INVOICE_DESCRIPTION,CREATION_TIMESTAMP,CREATION_USER)
        SELECT distinct ORG.ORDER_ID,XOM.ORDER_REF,XOM.ORDER_DESCRIPTION,XOM.ORDER_STATUS,Format_written_amount(XOM.ORDER_LINE_AMOUNT),XOM.INVOICE_REFERENCE,Format_date(XOM.INVOICE_DATE),XOM.INVOICE_STATUS,XOM.INVOICE_HOLD_REASON,Format_written_amount(XOM.INVOICE_AMOUNT),XOM.INVOICE_DESCRIPTION,SYSDATE,USER 
        FROM XXBCM_ORDER_MGT XOM
        INNER JOIN XXBCM_ORDER ORG ON ORG.ORDER_REF=SUBSTR(XOM.ORDER_REF,1,5)
        WHERE XOM.ORDER_REF like '%-%' order by XOM.ORDER_REF,XOM.INVOICE_REFERENCE
        --AND  NOT EXISTS (SELECT 1 FROM XXBCM_INVOICE DEST WHERE DEST.INVOICE_REFERENCE=XOM.INVOICE_REFERENCE AND DEST.ORDER_REF=XOM.ORDER_REF)
        ;
        
    END P3_IMPORT;
 
 
 
    
--By Patrick MICHEL
END BMC_IMPORT;

/
 --a summary of Orders with their corresponding list of distinct invoices and their total amount
CREATE VIEW P4_Orders_summary AS 
    SELECT
        to_number(substr(xo.order_ref,3)) as "Order Reference",to_char(xo.order_date,'Mon-RR') as "Order Period",xs.supplier_name as "Supplier Name",
        to_char(xo.order_total_amount,'99,999,990.00') as "Order Total Amount",
        xo.order_status as "Order Status",xi.invoice_reference as "Invoice Reference", to_char(xi.invoice_amount,'99,999,990.00') as "Invoice Total Amount", 
        BMC_IMPORT.Order_Action(xo.order_id) AS Action
    FROM    
       (xxbcm_invoice xi inner join xxbcm_order xo on xi.order_id=xo.order_id)
        inner join xxbcm_supplier xs on xo.supplier_id=xs.supplier_id  order by 1;
   

--THIRD highest Order Total Amount
CREATE VIEW P5_3th_Order_Total_Amount AS 
    SELECT
       to_number(substr(xo.order_ref,3)) as "Order Reference",
       to_char(xo.order_date,'Month Day,RRRR') as "Order Date",
       upper(xs.supplier_name) as "Supplier Name",
       to_char(xo.order_total_amount,'99,999,990.00') as "Order Total Amount",
       xo.order_status as "Order Status",
       BMC_IMPORT.Invoice_List(xo.order_id) as "Invoice Reference"
    FROM    
       xxbcm_order xo inner join xxbcm_supplier xs on xo.supplier_id=xs.supplier_id
       where xo.order_id =BMC_IMPORT.Nth_highest_Amount(3);

--List all suppliers
CREATE VIEW P6_List_all_suppliers AS 
SELECT
xs.supplier_name as "Supplier Name",
xc.supp_contact_name as "Supplier Contact Name",
regexp_substr( xc.supp_contact_number,'[^,]+',1,1)as "Supplier Contact No. 1",
regexp_substr( xc.supp_contact_number,'[^,]+',1,2) as "Supplier Contact No. 2",
sxo.TT_order as "Total Orders",
sxo.TT_Amount as "Order Total Amount"

FROM    
    ((select count(1) as TT_order,sum(xo.ORDER_TOTAL_AMOUNT) TT_Amount, xo.SUPPLIER_ID from xxbcm_order xo where  xo.ORDER_DATE between '01-JAN-2017' and '31-AUG-2017' group by xo.SUPPLIER_ID) sxo
    inner join xxbcm_supplier xs on sxo.supplier_id=xs.supplier_id)
    inner join xxbcm_contact xc on xs.contact_id=xc.contact_id;
    

COMMIT;
