!C FILE  5(KIND=DISK,TITLE='D3/DATA',DEPENDENTSPECS=.TRUE.)
!C FILE  6(KIND=PRINTER)
!C $RESET FREE
!C      NAVN:MAIN
!C 
!C ***********************************************************************
!C      D3-PROGRAM TIL BEREGNING AF STR@MNINGSFORHOLDENE I OG OMKRING EN *
!C      M@LLE AF DARRIEUS-TYPEN MED H@JST 3 BLADE,DER B$DE KAN V#RE LIGE *
!C      (GIROMILL) ELLER HVOR BLADFORMEN F@LGER EN PARABEL.SETVINKLEN MEL*
!C      LEM KORDE-OG TANGENTRETNINGEN FOR BEV#GELSESRETNINGEN AF FJERDE- *
!C      DELSPUNKTET ER SAT LIG NULL I ROUTINE BLAD.BLADENES INDBYRDES BE-*
!C      LIGGENHED KAN VARIERES.                                          *
!C      INDDATA:EFTER INDL#SNING AF PROFILDATA L#SES                     *
!C              UINF,DTETA,RPM,C                                         *
!C                H0,A,B,,BSAF                                           *
!C                 RO,ANY,EPS1,ARES                                      *
!C                  NOR,NETO,NB,NOL                                      *
!C                  ITALX,ITALY,ITALZ                                    *
!C                  CRANK(BLADNR)                                        *
!C      UDDATA:PR#STATIONSDATA FOR M@LLEN(SOM FUNKTION AF TIDEN) OG      *
!C             HVIRVELPOSITIONERNE SKRIVES P$ FIL 10 TIL OPTEGNING       *
!C             VED HJ#LP AF PROGRAMPAKKEN GPGS(PROGRAM A1)               *
!C    EXTENDED FOR USE WITH AIRFOIL PITCHING(FI0DOT)                     *
!C ***********************************************************************
!C    PS: IF XY-PLANE CROSS IN H/2, ALL SPEEDS ARE 0 THIS IS WEARED!
!C 
      program Main
      
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      INTEGER, PARAMETER:: ID=300,JD=ID-1
      COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
      COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),
     &CD(3,299)
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
      COMMON/LAST/FR(3,299,8000),FT(3,299,8000),FB(3,299,8000)
      COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)
      COMMON/BLAEST/VIND(300,3),UINF
      COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     & KMNET
      COMMON/RENUM/H2(3,300,8000,3),V2(3,300,8000,3)
      COMMON/PERTU/SWB(3,299,3)
      COMMON/SLIP/POINT(10,10,20,3),HAS(10,10,20,3),ITALX,ITALY,ITALZ
      COMMON/INDDAT/TA1(2),TCL1(2),TCD1(2),
     -TA2(2),TCL2(2),TCD2(2),
     -TA3(2),TCL3(2),TCD3(2),
     -TA4(2),TCL4(2),TCD4(2),
     -TA5(2),TCL5(2),TCD5(2), 
     -TA1F(11),TCL1F(11),TCD1F(11),
     -TA1T(11),TCL1T(11),TCD1T(11),
     -TA2F(11),TCL2F(11),TCD2F(11),
     -TA2T(11),TCL2T(11),TCD2T(11),
     -TA3F(11),TCL3F(11),TCD3F(11),
     -TA3T(11),TCL3T(11),TCD3T(11),
     -TA4F(11),TCL4F(11),TCD4F(11),
     -TA4T(11),TCL4T(11),TCD4T(11),     
     -TA5F(11),TCL5F(11),TCD5F(11), 
     -TA5T(11),TCL5T(11),TCD5T(11), 
     -TAH(12),TCLH(12),TCDH(12),
     -R1,R2,R3,R4,R5
      COMMON/LWRITE/BOOLPRINT
      INTEGER SHAPE,IO
      COMMON/VAR/IT
      COMMON/STYR/IRUNS,IBSNIT,INOL,KITE
      REAL PITCHOFFD,PITCHOFF,CRANKD(3)
!C 
       DIMENSION TSR(299),TPOSI(8000,2)
       DATA TSR,DSPAN,BETA,FI0 /299*0.0,299*0.0,299*0.0,299*0.0/
       DATA (((FT(I,J,K),I=1,3),J=1,299),K=1,8000) /7176000*0.0/
       DATA (((FR(I,J,K),I=1,3),J=1,299),K=1,8000) /7176000*0.0/
       DATA (((FB(I,J,K),I=1,3),J=1,299),K=1,8000) /7176000*0.0/


!CDATA ((A(I,J), I=1,5,2), J=1,5) /15*1.0/  ! initialization by implied-DO list
!CCOMMON/LAST/FR(3,299,8000),FT(3,299,8000),FB(3,299,8000)
!C     EXTERNAL LINPLT
       LOGICAL LARGEROTOR,BSWITCH1
       LOGICAL TEST
       LOGICAL CH/'M'/,CF/'*'/
       LOGICAL BOOLPRINT
       LOGICAL BSWITCH1=.FALSE.
       BOOLPRINT=.FALSE.
       LARGEROTOR=.FALSE.

!C*********************************       
       PI=4.*ATAN(1.)
!C*********************************
!C 
!C      INDL#SNING AF REYNOLDSTAL
!C 
	 OPEN(6,FILE='RESULT.DAT',STATUS='OLD',IOSTAT=IO)
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open RESULT.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF
       OPEN(5,FILE='D3_DATA.SEQ',STATUS='OLD',IOSTAT=IO)
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open D3_DATA.SEQ (IOSTAT=', IO, ')'
         STOP
       ENDIF
       IF(BOOLPRINT.EQ..TRUE.) THEN       
       OPEN(8,FILE='BIOTB.DAT')
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open BIOTB.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF      
       OPEN(9,FILE='BIOTL.DAT')
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open BIOTL.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF      
       OPEN(10,FILE='BIOTR.DAT')
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open BIOTR.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF     
       OPEN(11,FILE='CLCDOUT.DAT')
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open CLCDOUT.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF
       ENDIF
!C      INPUT DATA    
       READ(5,*)
       READ(5,*)BOOLPRINT
       READ(5,101) R1,R2,R3,R4,R5
       WRITE(6,102)
       WRITE(6,111) R1,R2,R3,R4,R5
101    FORMAT( 5ES10.2)
102    FORMAT(' ','    R1        R2        R3        R4        R5')
103    FORMAT(' ',' ')
104    FORMAT(' ','   ALFA   CLF    CDF    ALFA     CLT    CDT')
111    FORMAT(' ',5(EN10.1,X))
!C 
!C      INDL#SNING AF CL OG CD V#RDIER
!C      F......FREM
!C      T......TILBAGE
!C 
       WRITE(6,104)
       DO 11 M=1,2
         READ (5,1000) TA1(M),TCL1(M),TCD1(M)
         WRITE(6,1010) TA1(M),TCL1(M),TCD1(M)
         READ (5,1000) TA2(M),TCL2(M),TCD2(M)
         WRITE(6,1010) TA2(M),TCL2(M),TCD2(M)
         READ (5,1000) TA3(M),TCL3(M),TCD3(M)
         WRITE(6,1010) TA3(M),TCL3(M),TCD3(M)
         READ (5,1000) TA4(M),TCL4(M),TCD4(M)
         WRITE(6,1010) TA4(M),TCL4(M),TCD4(M)
         READ (5,1000) TA5(M),TCL5(M),TCD5(M)
         WRITE(6,1010) TA5(M),TCL5(M),TCD5(M)
1000   FORMAT( F5.1,F7.3,F7.4)
1010   FORMAT(' ',F7.1,F7.3,F7.4)
11     CONTINUE
       DO 12 M=1,11
        READ(5,1001)TA1F(M),TCL1F(M),TCD1F(M),TA1T(M),TCL1T(M),TCD1T(M)
        WRITE(6,1011)TA1F(M),TCL1F(M),TCD1F(M),TA1T(M),TCL1T(M),TCD1T(M)
        READ(5,1001)TA2F(M),TCL2F(M),TCD2F(M),TA2T(M),TCL2T(M),TCD2T(M)
        WRITE(6,1011)TA2F(M),TCL2F(M),TCD2F(M),TA2T(M),TCL2T(M),TCD2T(M)
        READ(5,1001)TA3F(M),TCL3F(M),TCD3F(M),TA3T(M),TCL3T(M),TCD3T(M)
        WRITE(6,1011)TA3F(M),TCL3F(M),TCD3F(M),TA3T(M),TCL3T(M),TCD3T(M)
        READ(5,1001)TA4F(M),TCL4F(M),TCD4F(M),TA4T(M),TCL4T(M),TCD4T(M)
        WRITE(6,1011)TA4F(M),TCL4F(M),TCD4F(M),TA4T(M),TCL4T(M),TCD4T(M)
        READ(5,1001)TA5F(M),TCL5F(M),TCD5F(M),TA5T(M),TCL5T(M),TCD5T(M)
        WRITE(6,1011)TA5F(M),TCL5F(M),TCD5F(M),TA5T(M),TCL5T(M),TCD5T(M)
12     CONTINUE
!C
!C    WRITE(6,103)
1001   FORMAT( F5.1,F7.3,F7.4,F5.1,F7.3,F7.4)
1011   FORMAT(' ',F7.1,F7.3,F7.4,F7.1,F7.3,F7.4)
1012   FORMAT(F5.1,F7.3,F7.4)
       DO 13 M=1,12
        READ(5,1012)TAH(M),TCLH(M),TCDH(M)
        WRITE(6,1010)TAH(M),TCLH(M),TCDH(M)
13     CONTINUE
      WRITE(6,103)
      READ(5,400) UINF,DTETAD,RPM,C,FI0DOT
      READ(5,401) H0,A,B,BSAF,HSTAR
      READ(5,402) RO,ANY,EPS1,ARES,RC
      READ(5,403) NOR,NETO,NB,NOL
      READ(5,404) ITALX,ITALY,ITALZ
      READ(5,506)(CRANKD(I),I=1,NB),PITCHOFFD
400   FORMAT(2X,F5.2,2(2X,F5.1),2X,F7.4,2X,F7.4)
401   FORMAT(5X,F5.1,5X,F7.4,5X,F10.4,5X,F8.5,5X,F8.5)
402   FORMAT(5X,F5.2,4(5X,E10.2))
403   FORMAT(4(5X,I3))
404   FORMAT(3(5X,I3))
506   FORMAT(3(4X,F6.1),4X,F6.1)
      IF (ABS(UINF) .LT. 1E-12) THEN 
          WRITE(6,*) 'ERROR: UINF MUST BE GREATER THAN 0. M/S'
          STOP
      ENDIF
      IF (NOL .LE. 4) THEN
          WRITE(6,*) 'ERROR: NOL must be > 4'
          STOP
      ENDIF
      IF (NB .LT. 1 .OR. NB .GT. 3) THEN
          WRITE(6,*) 'ERROR: NB must be 1-3'
          STOP
      ENDIF
      IF (ITALX .LT. 2 .OR. ITALY .LT. 2 .OR. ITALZ .LT. 2) THEN
          WRITE(6,*) 'ERROR: ITALX, ITALY, ITALZ must be >= 2'
          STOP
      ENDIF
      IF (B.GT.-1000.)SHAPE=1
      IF ((B.GT.-2000.).AND.(B.LT.-1000.))SHAPE=2
      IF ((B.LT.-3000.))SHAPE=3
      SELECT CASE (SHAPE)
      CASE(1)
          WRITE(6,501)
      CASE(2)
          WRITE(6,502)
      CASE(3)
          WRITE(6,*) 'MODIFIED TROPOSKIEN ROTOR SHAPE'
          OPEN(7,FILE='DeepWind-Blade-form.dat',STATUS='OLD',IOSTAT=IO)
          IF (IO .NE. 0) THEN
              WRITE(6,*) 'ERROR: Cannot open DeepWind-Blade-form.dat (
     -         IOSTAT=', IO, ')'
              STOP
          ENDIF          
          J=1
          DO I=1,29 
             READ(7,*,IOSTAT=IO)RS(J,2),RS(J,1)
             J=J+1
          END DO
          CLOSE(7)

      END SELECT
112   FORMAT(6X,(I2,F12.9,5X,E9.2))
!C 
!C      UDSKRIVNING AF INDATAKONSTANTER
!C       IF(B .GT.-1000.) GOTO 28
!C       WRITE(6,502)
!C       GOTO 29
!C28    WRITE(6,501)
29    WRITE(6,406)H0,A,B,BSAF,HSTAR
       WRITE(6,1260)
       WRITE(6,503)
       WRITE(6,407)RO,ANY,EPS1,ARES
       WRITE(6,1260)
       WRITE(6,504)
       WRITE(6,408)NOR,NETO,NB,NOL
       WRITE(6,1260)
       WRITE(6,505)
       WRITE(6,409)ITALX,ITALY,ITALZ
       WRITE(6,1260)
       WRITE(6,410)
       WRITE(6,411)(CRANKD(I),I=1,NB), PITCHOFFD
       WRITE(6,1260)
       WRITE(6,500)
       WRITE(6,405)UINF,DTETAD,RPM,C,FI0DOT
!C      FORMATSPECIFIKATION
!C 
405   FORMAT(' ',5X,F5.2,2(5X,F5.1),3(5X,F7.4))
406   FORMAT(' ',5X,F5.1,6X,F7.4,5X,F10.4,2(9X,F8.5))
407   FORMAT(' ',5X,F5.2,3(5X,E10.2))
408   FORMAT(' ',4(5X,I3))
409   FORMAT(' ',3(5X,I3))
410   FORMAT(' ','CRANKVINKEL[DEG]:')
411   FORMAT(' ',3(4X,F6.1),4X,F6.1)
!C 
!C      SPECIFIKATION AF OVERSKRIFT FOR KONSTANTER
!C 
500   FORMAT(' ','     UINF       DTETA    RPM       KORDE      ')
501   FORMAT(' ','GIROMILL:'/'       HØJDE  BLADHÆLD. A    ORDINATVÆRDI
     - B    BSAF ')
502   FORMAT(' ','DARRIEUS:'/'       HØJDE        R/H0       INDIKATOR  
     -      BSAF')
503   FORMAT(' ','      RO           NY            EPS1         RESIDU')
504   FORMAT(' ','      NOR    NETO     NB      NOL ')
505   FORMAT(' ','ANTAL PKT.:'/'        X       Y       Z  RETNING')
507   FORMAT(' ','TSRMIDT=',F10.5,/' ','SOLIDITET=',F8.5,/' ','AREF=',F1
     -5.4)
       
       OMEGA=PI*RPM/30.
       DTETA=DTETAD*PI/180.
       DT=DTETA/OMEGA
       PITCHOFF=PITCHOFFD*PI/180.
       IF(SHAPE.EQ.2) GOTO 700
       !IF(SHAPE.EQ.3) THEN FIND RMAX
!C     LINEAR SHAPE=1: GIROMILL
       RMIDT=(A+B)*H0
       AREF=(2*B+A)*H0*H0
       GOTO 701
700    RMIDT=A*H0 ! PARABEL
701    SOL=NB*C/RMIDT
!C 
       DO 3 I=1,NB
          CRANK(I)=CRANKD(I)*PI/180.
3      CONTINUE
!C 
!C      ANTAL SNIT I H@JDEN:NOL1 STYK
!C      ANTAL TOTALE LAG   :NOL(6,8....STYK)
!C      BEREGNINGSPUNKT I MIDTPUNKT AF LAG
!C 
      LARGEROTOR=.FALSE.
!C     IF(SQRT((OMEGA*RMIDT)*(OMEGA*RMIDT)+UINF*UINF).GT.30.) THEN
!C         LARGEROTOR=.TRUE.
!C         WRITE(6,*)'ROTOR CONFIG ', 'LARGE'
!C     ENDIF
       NOL1=NOL+1
!C *******************************************************
!C      BLADGEOMETRI BESTEMMES  OG PITCH INTIIERES       *
!C *******************************************************
       CALL BLAD(PITCHOFF)
       AREF=0.0
       DO 42 J=1,NOL
         AREF=AREF+
     /   (BLSNIT(1,J,2)+BLSNIT(1,J+1,2))*(BLSNIT(1,J+1,3)-BLSNIT(1,J,3))
42     CONTINUE
!C 
!C 
!C      BEREGNING AF VIND I  BEREGNINGSPKT OG I SNITTENE
!C 
       DO 30 J=1,NOL
          VIND(J,1)=UINF
          VIND(J,2)=0.0
          VIND(J,3)=0.0
!C 
!C         BEREGNING AF LOKAL TIP-SPEED-RATIO
          TSR(J)=OMEGA*(BLSNIT(1,J,2)+BLSNIT(1,J+1,2))/2./UINF
30     CONTINUE
       VIND(NOL1,1)=UINF
       VIND(NOL1,2)=0.
       VIND(NOL1,3)=0.
!C 
!C      BEREGNING AF #KVATORIEL TIP-SPEED-RATIO
!C 
       TSRM=OMEGA*RMIDT/UINF
       WRITE(6,507)TSRM,SOL,AREF
!C    INITIALISATION OF MARIXES
!C    GAMME( , ,1) CORRESPONDS TO THE BOUND VORTEX AT T=0,K=1
!C    GAMME( , ,2) CORRESPONDS TO THE VORTEX SHED 1*DT=DTETA/OMEGA,  K=2
!C    THE VORTEX CORRESPONING TO KMNET IS THE ONE SHED (KMNET-1)*DT AGO
       DO 6 I=1,3
         DO 7 J=1,300
           DO 8 K=1,8000
                GAMME(I,J,K)=0.0
                DO 9 L=1,3
                   V1(I,J,K,L)=0.0
                   V2(I,J,K,L)=0.0
                   H1(I,J,K,L)=0.0
                   H2(I,J,K,L)=0.0
9               CONTINUE
8          CONTINUE
           IF(J.EQ.300)GOTO 7
           UREL(I,J)=0.0
           CL(I,J)=0.0
           CD(I,J)=0.0
           ALFAF(I,J)=0.0
           ALFA(I,J) =0.0
7        CONTINUE
6      CONTINUE
!C 
!C      INITIALISERING AF IRUN OG TEST
       IRUN=0
       TEST=.FALSE.
       OPEN(25,FILE='RES.DAT',STATUS='OLD',IOSTAT=IO)
       IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open RES.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF
       
!C 
!C      FASTL#GGELSE AF NETKARAKTERISTIKA
!C      IR EQ TO NUMBER OF INCREMENTAL ANGULAR STEPS
!C 
       IR=NInt(2.0*PI/DTETA) !IR: Number of steps  for one turn
       ! Validate that timestep divides rotation evenly
       EXPECTED_DTETA = 2.0*PI/REAL(IR)
       IF (ABS(DTETA-EXPECTED_DTETA)/DTETA .GT. 1.0E-6) THEN
          WRITE(6,*) 'WARNING: DTETA does not evenly divide rotation'
          WRITE(6,*) 'DTETA=', DTETA, ' Expected=', EXPECTED_DTETA
       ENDIF


       KRUN=NOR*IR
       KMAKS=3*KRUN
!C      ARRAY FOR FORCES MÅ IKKE OVERSTIGE DIM 8000->DYNAMISK ARRAYALLOKERING
       KMNET=NETO*IR+1 !Original correct formula: 1 bound + NETO revolutions
       IF (KMNET .GT. 8000) THEN
          WRITE(6,*) 'ERROR: KMNET (', KMNET, ') exceeds MAX dimension 8
     -000       .'
          STOP
       ENDIF
       NPSI=IR+1!CHECK WITH BOUND VORTEX INDEXING.:. NO OF BOUND VORTEX INDEX 2PI LATER IS NPSI (correct: IR+1)
       WRITE(6,1130)
       WRITE(6,1140)KMNET,NPSI,KRUN,KMAKS
       WRITE(6,1150)
       WRITE(6,1100)
       WRITE(6,1160)
       WRITE(6,1110)
!C    *******************************************************
!C                                                            *
!C    
!C      ELAPSED TIME T =IRUN*DT
!C      FI0DOT*T=FI0
       
       DO 36 J=1,NOL
         BLRAD=(BLSNIT(1,J,2)+BLSNIT(1,J+1,2))/2.
         BLHZ=(BLSNIT(1,J,3)+BLSNIT(1,J+1,3))/2.
         FI0(J)=SIN(FI0DOT*IRUN*DT/180.*PI)/36.0
         FI0DEG=FI0(J)*180./PI
         WRITE(6,1170)J,TSR(J),DSPAN(J),BLHZ,BLRAD,FI0DEG,BETA(J)
36     CONTINUE
!C 
         WRITE(6,1260)
         WRITE(6,1190)
         WRITE(6,1210)
!C 
!C      OPSTART
       CALL START !VORTEX MESH GENERATED BACKWARDS IN TIME
!C 
!C 
!C      START AF SIMULERING
!C 
  
1      CALL NETHAS
       IF(TEST)GOTO 9999
!C    HERE THE RUN -LOOP IS UPDATED
! After IRUN increment — update all FI0 entries (was FI0(J)=... which used an uninitialized J)       
       IRUN=IRUN+1
       TETAD=IRUN*DTETA*180./PI
       DO J=1,NOL
         FI0(J)=SIN(FI0DOT*IRUN*DT/180.*PI)/36.
       END DO
!C 
       CALL FLYT
       CALL VORTEX(ARES)
!C 
       DO 31 I=1,NB
         WRITE(6,1270)
         WRITE(6,1180) IRUN,TETAD,IT
         WRITE(6,1270)
         DO 32 J=1,NOL
           VELX=(SWB(I,J,1)/VIND(J,1))+1.0
           VELY=(SWB(I,J,2)+VIND(J,2))/VIND(J,1)
           VELZ=(SWB(I,J,3)+VIND(J,3))/VIND(J,1)
           REY=UREL(I,J)*C/ANY
           ALFAD=ALFA(I,J)*180./PI
          IF(LARGEROTOR)THEN
              WRITE(6,1201)TETAD,J,ALFAD,UREL(I,J),REY,CL(I,J),CD(I,J),
     -        VELX,VELY,VELZ,GAMME(I,J,1),I 
          ELSE
              WRITE(6,1200)TETAD,J,ALFAD,UREL(I,J),REY,CL(I,J),CD(I,J),
     -        VELX,VELY,VELZ,GAMME(I,J,1),I
          ENDIF
          IF (J.EQ.NOL/2) THEN 
             WRITE(25,1200)TETAD,J,ALFAD,UREL(I,J),REY,CL(I,J),CD(I,J),
     -       VELX,VELY,VELZ,GAMME(I,J,1),I
          ENDIF
32      CONTINUE
31     CONTINUE
!C
       CALL FORCES
! Replace arithmetic IF that depended on sign(GPERN) with explicit control flow      
       GPERT=0.0
       GPERN=0.0
       DO 20 I=1,NB
         DO 21 J=1,NOL
            GPERT=AMAX1(ABS(GAMME(I,J,1)-GAMME(I,J,NPSI)),GPERT)
            GPERN=AMAX1(ABS(GAMME(I,J,1)),GPERN)
21       CONTINUE
20     CONTINUE
       IF(GPERN .LE. 0.0) THEN
          GOTO 9999
       ELSE
          GG=GPERT/GPERN
       ENDIF
       IF(IRUN.GE.KMAKS.OR.(GG.LT.EPS1.AND.IRUN.GT.KRUN))TEST=.TRUE.
       GOTO 1
9999   TSUM=0.
 
!C
!C     BEREGNING AF M@LLENS MOMENT (TPOSI) OVER DEN SIDSTE OMGANG
!C
!C    #############################################
!C    IRUN+1-L becomes 0
!C    =>FT becomes indeterminate because of 0 index!
!C    #############################################
      IF (IRUN.EQ. IR) THEN  
         WRITE(6,*) 'NETGRID CONDITIONS IRUN+1-IR.LT.1'
      ENDIF
      ! Guard historic access FT(I,J,IRUN+1-L) so source index is valid
      ! (replace inner block in the TPOSI accumulation loop)
      DO 22 L=1,IR
         SRC = IRUN+1-L
         TPOSI(L,1)=DTETA*(SRC)*180./PI
         TPOSI(L,2)=0.0
         IF (SRC .GT.1 ) THEN
          DO 23 I=1,NB
           DO 24 J=1,NOL
             TPOSI(L,2)=TPOSI(L,2)
     &         +FT(I,J,SRC)*(BLSNIT(1,J,2)+BLSNIT(1,J+1,2))/2.
24         CONTINUE
23        CONTINUE
         ELSE
!C        NO HISTORIC FORCES AVAILABLE FOR THIS L(EARLY IN SIMULATION)-LEAVE TPOSI(L,2)=0
         ENDIF
22     CONTINUE
!C 
!C      BEREGNING AF M@LLENS MIDDELMOMENT SAMT EFFEKTKOEFFICIENT
!C 
       DO 25 L=1,IR
         TSUM=TSUM+TPOSI(L,2)
25     CONTINUE
       TMEAN=TSUM/IR
       CP=2.*TMEAN*OMEGA/RO/(UINF**3)/AREF
       DO 33 K=1,IR
         WRITE(6,1260)
         WRITE(6,1230)K
         IF(LARGEROTOR) THEN 
             WRITE(6,1245)
         ELSE 
             WRITE(6,1240) 
             ENDIF
         DX=1.0
         IF (LARGEROTOR)DX=1000.
         DO 34 I=1,NB
           DO 35 J=1,NOL
            WRITE(6,1250)I,J,FR(I,J,IRUN+1-K)/DX,
     -                      FT(I,J,IRUN+1-K)/DX,
     -                      FB(I,J,IRUN+1-K)/DX
35         CONTINUE
34       CONTINUE
         WRITE(6,1270)
         IF (LARGEROTOR)THEN 
         WRITE(6,2220)TPOSI(K,2)/1000.,TPOSI(K,1)
         ELSE 
         WRITE(6,1220)TPOSI(K,2),TPOSI(K,1) 
         ENDIF
33     CONTINUE
       IF (LARGEROTOR) THEN 
          WRITE(6,2000)CP,TMEAN/1000.
       ELSE
          WRITE(6,2)CP,TMEAN
       ENDIF
       CALL BSPD3
       WRITE(6,1100)
       WRITE(6,'("# AZI[GRD]     MOMENT[Nm]")')
       DO 37 K=1,IR
           WRITE(6,1225)TPOSI(K,1),TPOSI(K,2)
37     CONTINUE
!C      CALL TITLES('MOMENT-KURVE',12,'M',1,'TETA',4)
!C      CALL FILLUP(+1,CF,1)
!C      CALL SVPLOT(1,80,CH,IR,TPOSI,129,55,IER)
!C 

!      DO 1300 INS=1,NOL1
!         CALL PLOT(INS)
!1300  CONTINUE
!      REWIND 10
!      WRITE(10)H1,KMNET,NB,NOL,A,B,H0
2     FORMAT(' ','CP= ',F10.5,10X,'MOMENT= ',F15.3,'  Nm')
2000  FORMAT(' ','CP= ',F10.5,10X,'MOMENT= ',F15.3,' kNm')
1100  FORMAT(1H1)
1110  FORMAT('#',18X,80('-'))
1130  FORMAT(' '/21X,'KMNET',11X,'NPSI',11X,'KRUN',10X,'KMAKS')
1140  FORMAT(' ',8X,4(10X,I5))
1150  FORMAT(' ',20X,50('-'))
1160  FORMAT(' ',18X,'BRSNIT_NR',7X,'TSR',10X,'DSPAN',15X,'BRSNIT-Z-Y',1
     -5X,'FI0',15X,'BETA')
1170  FORMAT(' ',(20X,I5,6(5X,F10.5)))
1180  FORMAT('#',121X,'IRUN:',I3/,'#',121X,'TETA:',F6.1/,'#',121X,
     -'IT:',I4)
1190  FORMAT('#',7X,'J',7X,'ALFA',6X,'UREL',9X,'REY',4X,'CL',6X,'CD',9X,
     -'V2X/VIND',7X,'V2Y/VIND',7X,'V2Z/VIND',8X,'GAMMAB',1X,'BLAD NR:')
1200  FORMAT(F6.1,' ',I3,2(1X,F10.3),1X,EN10.0,2(1X,F7.4),1X,3(5X,F10.5)
     -,F15.5,5X,I3)
1201  FORMAT(F6.1,' ',I3,2(1X,F10.3),1X,EN10.0,2(1X,F7.4),1X,3(5X,F10.5)
     -,F15.5,5X,I3)
1210   FORMAT('#',120('-'))
1220   FORMAT(' '/'# MOMENT  ',EN11.2,'  Nm VED TETA ',F10.1)
1225   FORMAT(' ',(F7.1,5X,EN12.3))
2220   FORMAT(' '/'# MOMENT  ',EN11.2,' kNm VED TETA ',F10.1)
1230   FORMAT(' '/'# POSITION_NR',I5)
1240   FORMAT('#',4X,'I',6X,'J',15X,'FR Nm',12X,'FT Nm',12X,'FB Nm')
1245   FORMAT('#',4X,'I',6X,'J',15X,'FR kNm',11X,'FT kNm',11X,'FB kNm')       
1250   FORMAT(' ',2(I5,2X),3(F15.3,2X))
1260   FORMAT(' '//)
1270   FORMAT(' ')

             CLOSE(5)
	  CLOSE(6)
        IF(BOOLPRINT.EQ..TRUE.) THEN   
        CLOSE(8)
        CLOSE(9)
        CLOSE(10)
        ENDIF
        CLOSE(11)
        CLOSE(25)
       STOP
      END program Main
      
       SUBROUTINE AFINTA(ALFAD,NT,IT,TV,CLV,CDV,CLA,CDA)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       DIMENSION TV(NT),CLV(NT),CDV(NT)
       DATA N1,N2,N3/2,11,12/
!C 
       ALFADN=ABS(ALFAD)
       ITM=IT-2
       IF (ITM) 1,2,3
1      N=N1-1
       GOTO 4
2      N=N2-1
       GOTO 4
3      N=N3-1
4      DO 10 I=1,N
         J=I
         IF (ALFADN .GT.TV(I) .AND.ALFADN .LE.TV(I+1)) GOTO 20
10     CONTINUE
20     X=(ALFADN-TV(J))/(TV(J+1)-TV(J))
!C      WRITE(6,100) ALFADN,TV(J),TV(J+1)
!C  100 FORMAT(' ',F10.5,10X,F10.5,10X,F10.5)
!C 
!C      LINE#R INTERPOLATION
       CLA=CLV(J)+X*(CLV(J+1)-CLV(J))
       CDA=CDV(J)+X*(CDV(J+1)-CDV(J))
!C 
!C 
       RETURN
       END
!C 
       SUBROUTINE BIOTg(X,Y,Z,GAMMA,W)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       DIMENSION DIR(3),VA(3),VB(3),V(3),X(3),Y(3),Z(3),W(3)
!C ***********************************************************************
!C      BIOT BEREGNER DOWNWASHVEKTOR I ST@RRELSE OG RETNING I ET PUNKT
!C      Z1,Z2,Z3 FRA EN HVIRVEL MED ENDEPUNKTER A(X1,X2,X3) OG B(Y1,Y2,Y3)
!C      OG EN STYRKE GAMMA.POSITIV ORIENRERING AF HVIRVEL SET FRA A(
!C      H@JREH$NDSREGEL)
!C ***********************************************************************
       PI=3.14159625
       VL=0.
       A=0.
       B=0.
       VAL=0.
       VBL=0.
       EPS=1.00E-06
!C      V:VEKTOR Y-X OG VL:VEKTORL#NGDEN
!C      VA       Z-X
!C      VB       Z-Y
!C 
       DO 1 L=1,3
         VA(L)=Z(L)-X(L)
         VB(L)=Z(L)-Y(L)
          V(L)=Y(L)-X(L)
         VL=VL+V(L)**2
1      CONTINUE
       VL=SQRT(VL)
       DO 2 L=1,3
         A=A+VA(L)*V(L)
         B=B+VB(L)*V(L)
         VAL=VAL+VA(L)**2
         VBL=VBL+VB(L)**2
2      CONTINUE
!C 
!C      VINKLERNE ER FUNDET VED PROJEKTION
!C 
!C      RETNING AF INDUCERET HASTIGHED BESTEMMES
!C 
       DIR(1)=V(2)*VA(3)-VA(2)*V(3)
       DIR(2)=V(3)*VA(1)-VA(3)*V(1)
       DIR(3)=V(1)*VA(2)-VA(1)*V(2)
       AF=SQRT(DIR(1)**2+DIR(2)**2+DIR(3)**2)
       IF (AF/VL .GT. EPS )GOTO 3
       DO 5 L=1,3
         W(L)=0.
5      CONTINUE
       RETURN
3      COSA=A/SQRT(VAL)/VL
       COSB=B/SQRT(VBL)/VL
       WASH=GAMMA*(COSA-COSB)*VL/(AF*4.*PI)
       DO 4 L=1,3
         W(L)=DIR(L)*WASH/AF
4      CONTINUE
       RETURN
       END
!C


!C    newest code of biot-010314
      SUBROUTINE BIOT(X,Y,Z,GAMMA,RC,W)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      DIMENSION DIR(3),VA(3),VB(3),V(3),X(3),Y(3),Z(3),W(3)
      INTEGER IVORTEX
      COMMON/STYR/IRUNS,IBSNIT,INOL,KITE
      REAL*8 A,AF,AFS,B,VL,VL2,VAL,VAL2,VBL,VBL2,COSA,COSB,PI,WASH
!C ***********************************************************************
!C      BIOT BEREGNER DOWNWASHVEKTOR I ST@RRELSE OG RETNING I ET PUNKT
!C      Z1,Z2,Z3 FRA EN HVIRVEL MED ENDEPUNKTER A(X1,X2,X3) OG B(Y1,Y2,Y3)
!C      OG EN STYRKE GAMMA.POSITIV ORIENRERING AF HVIRVEL SET FRA A(
!C      H@JREH$NDSREGEL)
!C ***********************************************************************
       PI=3.1415926535897932384626433832795_8
      
!C ***********************************************************************
!C    IVORTEX=0 RANKINE n=0
!C    IVORTEX=1 SCULLY a**1/n/(a**2/n+rc**2/n); n=1
!C    IVORTEC=2 n=2
!C ***********************************************************************
     
      IVORTEX=2
       VL2=0.D0
       A=0.D0
       B=0.D0
       AF=0.D0
       AFS=0.D0
       VAL2=0.D0
       VBL2=0.D0
       EPS=1.00E-06_8
!C       RC=0.075*1.
!C      V:VEKTOR Y-X OG VL:VEKTORL#NGDEN
!C      VA       Z-X
!C      VB       Z-Y
!C 
       DO 1 L=1,3
         VA(L)=Z(L)-X(L)
         VB(L)=Z(L)-Y(L)
         V(L)=Y(L)-X(L)
         VL2=VL2+V(L)*V(L)
1      CONTINUE
       VL=SQRT(VL2)
       DIR(1)=V(2)*VA(3)-VA(2)*V(3)
       DIR(2)=V(3)*VA(1)-VA(3)*V(1)
       DIR(3)=V(1)*VA(2)-VA(1)*V(2)
!C       VL=SQRT(VL2)
!C       LENGTH OF VORTEX HAS MAY BE TO RELATED TO RC
       DO 2 L=1,3
         A=A+VA(L)*V(L)
         B=B+VB(L)*V(L)
         VAL2=VAL2+VA(L)*VA(L)
         VBL2=VBL2+VB(L)*VB(L)
         AF=AF+DIR(L)*DIR(L)
2      CONTINUE
       VAL=SQRT(VAL2)!VAL=|VA|
       VBL=SQRT(VBL2)!VBL=|VB|
       AF=SQRT(AF)!AF=|DIR|
!C 
!C      VINKLERNE ER FUNDET VED PROJEKTION
!C 
!C      RETNING AF INDUCERET HASTIGHED BESTEMMES
!C 
!C      AFS=AFSTAND FRA HVIRVEL TIL PUNKT=AF/VL
   
       IF(VL .LT.EPS)THEN
       !IF(BSWITCH1)WRITE(6,*)"VORTEX LINE ELEMENT LENGTH=0"
       !IF(BSWITCH1)WRITE(6,*)"{X1,X2,X3}", X
       !IF(BSWITCH1)WRITE(6,*)"{Y1,Y2,Y3}", Y
       GOTO 55       
       ENDIF
       IF(AF.LT.EPS)THEN
       !IF(BSWITCH1)WRITE(6,*)"DISTANCE FROM POINT TO VORTEX=0 OR VxVA=0"
       !IF(BSWITCH1)WRITE(6,*)"{Z1,Z2,Z3}", Z
       GOTO 55
       ENDIF
       GOTO 56
55     DO 5 L=1,3
         W(L)=0.0
5      CONTINUE
       RETURN
    
56     AFS=AF/VL      
       COSA=0.D0
       IF(VAL.GT.0.00001)COSA=A/(VAL*VL)
       COSB=0.D0
       IF(VBL.GT.0.00001)COSB=B/(VBL*VL)
!C
!C    DETERMINATION OF VORTEX WITH/WITHOUT VISKOSITY(SCULLY 1975)
!C
       !IF(IVORTEX.EQ.1)THEN
       !    IF(AFS .GT.RC) THEN
       !      WASH=GAMMA*(COSA-COSB)*1./(AFS*4.*PI)    
       !    ELSE
       !      WASH=GAMMA*(COSA-COSB)*AFS/(RC*RC*4.*PI)
       !    ENDIF
       !ENDIF
!       IF(IVORTEX.EQ.2) THEN
          WASH=GAMMA*(COSA-COSB)*AFS/((RC*RC+AFS*AFS)*4.*PI)
!       ENDIF
       DO 4 L=1,3
         W(L)=DIR(L)/AF*WASH
4      CONTINUE
       
       RETURN
      END

      SUBROUTINE BLAD(PITCHOFF)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
      COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)
      DIMENSION V(3)
      REAL*8 VL2
      REAL OFFSETPITCH

      GERADE(A,B,H0,Z)=A*Z+B*H0
      PARAB(A,H0,Z)=4.*A*Z*(1.-Z/H0)
!C 
!C ***********************************************************************
!C                                                                       *
!C      ROUTINEN FINDER SNITTENES KOORDINATER FOR FLERE BLADE TIL TIDS-  *
!C      PUNKT IRUN=0 SAMT BLADELEM. L#NGDE,H#LDNINGEN MOD AKSLEN SAMT    *
!C      SETVINKLEN FI0 I HVERT BEREGNINGSPUNKT                           *
!C      FOR EN M@LLE MED LIGE BLADE ER VINGENS H#LDNING TAN(BETA)=A OG   *
!C      SK#RINGSPUNKTET FOR VINGEN MED ORDINATEN BETEGNES B(I F.T DEN   *
!C      FYSISKE H@JDE H0).                                               *
!C      I PARABELTILF#LDET ANGIVER H0 FYSISK H@JDE,OG A RADIUSFORHOLDET  *
!C      FOR B MINDRE END -1000 ER DER KUN TALE OM EN PARABEL
!C      BSAF ANGIVES I.F.T. H0 OG ER MEDTAGET FOR AT KOMPENSERE FOR KANT *
!C      EFFEKTERNE.SNIT 2 OG 2' SIDSTE L#GGES I 1/3*BSAF*H0 FRA TIPPEN.  *
!C      MODIFICERET ROTORSHAPE BETINGELSE: B<-2000                       *
!C      13-10-2016:Q(N-C-S) KOORINATSYSTEMET LÆGGES I AKSEN HVOROM       *
!C      DREJNINGEN FI0(t)=C1*F(FI0_DOT*t), DVS AT VINKLEN TETA REGNES    *
!C      FRA O(X-Y-Z) GENNEM DREJNINGSPUNKTET Q                           *
!C ***********************************************************************
!C 
!C      NOL:NUMBER OF LAYERS-NOL1:TOTAL ANTAL SNIT OG NOL>4]
!C 
!C    OPTION A: B>-1000. MEANS H ROTOR WITH REAL OFFSET B AND GAIN A:             SHAPE=1    
!C    OPTION B: -2000<B<-1000. MEANS ORIDNARY PARABOLA LIKE ROTOR SHAPE:          SHAPE=2
!C    OPTION C: B<-3000 MEANS MODIFIED TROPOSKIEN SHAPE : (Z,Y)=(RS(.,1),RS(.,2): SHAPE=3
       
      INTEGER SHAPE
      IF (B.GT.-1000.)SHAPE=1
      IF ((B.GT.-2000.).AND.(B.LT.-1000.))SHAPE=2
      IF ((B.LT.-3000.))SHAPE=3    
!C      WRITE(6,*) ('ROTOR SHAPE IS: ',SHAPE)
!C    BLSNIT(NOB,NOL,X=1,Y=2,Z=3)
       OFFSETPITCH=PITCHOFF
       NOL1=NOL+1
       NOL2=NOL-1
       PI=4.*ATAN(1.)
       BLSNIT(1,1,1)=0.                                       !X=0
       BLSNIT(1,1,3)=0.                                       !Z=0
       BLSNIT(1,1,2)=GERADE(A,B,H0,0.)                        !DEFAULT Y(Z1)
       IF (SHAPE.EQ.2)BLSNIT(1,1,2)=PARAB(A,H0,0.)            !PARABOLA Y(Z1)
       IF (SHAPE.EQ.3)THEN
           BLSNIT(1,1,3)=RS(1,1)
           BLSNIT(1,1,2)=RS(1,2)                              !MODIFIED Y(Z1),
       ENDIF
       BLSNIT(1,2,3)=BSAF*H0/3. 
       BLSNIT(1,2,2)=GERADE(A,B,H0,BLSNIT(1,2,3))
       IF (SHAPE.EQ.2)BLSNIT(1,2,2)=PARAB(A,H0,BLSNIT(1,2,3))
       IF (SHAPE.EQ.3)THEN
           BLSNIT(1,2,3)=RS(2,1)
           BLSNIT(1,2,2)=RS(2,2)
       ENDIF
       BLSNIT(1,2,1)=0.
       DEL=H0*(1.-2.*BSAF)/REAL(NOL-4)
       DO 1 J=3,NOL2
         BLSNIT(1,J,3)=BSAF*H0+DEL*(J-3)
         BLSNIT(1,J,2)=GERADE(A,B,H0,BLSNIT(1,J,3))
         IF(SHAPE.EQ.2) BLSNIT(1,J,2)=PARAB(A,H0,BLSNIT(1,J,3))
         IF(SHAPE.EQ.3) THEN 
             BLSNIT(1,J,3)=RS(J,1)
             BLSNIT(1,J,2)=RS(J,2)
         ENDIF
         BLSNIT(1,J,1)=0.
1      CONTINUE
       BLSNIT(1,NOL,3)=(1.-BSAF/3.)*H0
       BLSNIT(1,NOL,2)=GERADE(A,B,H0,BLSNIT(1,NOL,3))
       IF(SHAPE.EQ.2) BLSNIT(1,NOL,2)=PARAB(A,H0,BLSNIT(1,NOL,3))
       IF(SHAPE.EQ.3) THEN
           BLSNIT(1,NOL,3)=RS(NOL,1)
           BLSNIT(1,NOL,2)=RS(NOL,2)
       ENDIF
       BLSNIT(1,NOL,1)=0.
       BLSNIT(1,NOL1,3)=H0
       BLSNIT(1,NOL1,2)=GERADE(A,B,H0,H0)
       IF(SHAPE.EQ.2) BLSNIT(1,NOL1,2)=PARAB(A,H0,H0)
       IF(SHAPE.EQ.3) THEN
           BLSNIT(1,NOL1,3)=RS(NOL1,1)
           BLSNIT(1,NOL1,2)=RS(NOL1,2)
       ENDIF
       BLSNIT(1,NOL1,1)=0.
       DO 5 J=1,NOL
         VL2=0.D0
         DO 6 L=1,3
           V(L)=BLSNIT(1,J+1,L)-BLSNIT(1,J,L)
           VL2= VL2+ V(L)**2
6        CONTINUE
         DSPAN(J)=SQRT(VL2)
         TANB=(BLSNIT(1,J+1,2)-BLSNIT(1,J,2))/(BLSNIT(1,J+1,3)-BLSNIT(1,
     -J,3))
         BETA(J)=ATAN(TANB)
!C 
!C        SETVINKLEN FI0 S#TTES LIG XX OG REGNES I RADIANER
!C 
           FI0(J)=0.0+OFFSETPITCH
           
!C         COMPENSATE FOR OFFSETTING MASTERBLADE AT TETA=0 RAD
!C 
5      CONTINUE
       IF(NB .EQ. 1) RETURN
       DO 2 I=2,NB
         DO 3 J=1,NOL1
         BLSNIT(I,J,3)=BLSNIT(1,J,3)
         BLSNIT(I,J,2)=BLSNIT(1,J,2)*COS(CRANK(I))
         BLSNIT(I,J,1)=-BLSNIT(1,J,1)*SIN(CRANK(I))
3        CONTINUE
2      CONTINUE
!C      WRITE(6,4) A,B,H0,NOL,CRANK(1),CRANK(2),CRANK(3)
!C    4 FORMAT(' ',3F5.3,I5,3(F5.2))
 !      RETURN
       END
!C 
!C 
      SUBROUTINE BSA(INDI,INB,INS,IH,SW)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       COMMON/SLIP/POINT(10,10,20,3),HAS(10,10,20,3),ITALX,ITALY,ITALZ
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     & KMNET
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       DIMENSION SW(3),X(3),Y(3),Z(3),W(3)

       COMMON/LWRITE/BOOLPRINT
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
       COMMON/STYR/IRUNS,IBSNIT,INOL,KITE
       
!C 
!C ***********************************************************************
!C      INDIKATOR=                                                       *
!C               1:INDFLYDELSE FRA BUNDEN,NO.1,NO.2,.....HVIRVEL MEDTAGES*
!C                 DEN K'TE UNDLADES                                     *
!C               2:    "        " NO.1,NO.2,........I PUNKT P$ BLAD      *
!C                                                                       *
!C               3:    "        " NO.2,NO.3,........    "                *
!C                                                                       *
!C      HVIRVELINIEN,SOM SK#RER PUNKTET,BLIVER IKKE MEDTAGET I BEREGNINGEN
!C                                                                       *
!C ***********************************************************************
!C 
!C      TIL BEREGNING AF INDUCEREDE HASTIGHEDER I PLANERNE GIVET VED
!C      ITALX,ITALY,ITALZ BENYTTES EN INDIKATOR,SOM S#TTES LIG 0 I
!C      KALDET.INB,INS,IH ER DA #KVIVALENT MED ITALX,ITALY,ITALZ
!C      DET NORMALE TILF#LDE SVARER TIL AT FINDE INDFL. FRA SSTR. I
!C      HVIRVELKNUDERNE.
!C 
       NOL1=NOL+1
       DO 1 L=1,3
         SW(L)=0.0
1      CONTINUE
       IF(INDI .GE. 1)GOTO 2
       DO 3 L=1,3
         Z(L)=POINT(INB,INS,IH,L)
3      CONTINUE
       INDI1=INDI+1
       GOTO 400
2      INDI1=INDI
       DO 4 L=1,3
         Z(L)=H1(INB,INS,IH,L)
4      CONTINUE
!C *****************************************************
!C      BEREGNING AF DE AFKASTEDE HVIRVLERS INDFLYDELSE*
!C *****************************************************
400    DO 5 I=1,NB
         DO 6 K=INDI1,KMNET
           DO 7 J=1,NOL1
             IF(J .EQ. NOL1)GOTO 99
             DO 8 L=1,3
               X(L)=H1(I,J,K,L)
               Y(L)=H1(I,J+1,K,L)
8            CONTINUE
             IF (K.EQ.1) GOTO 100
             GAMMA=GAMME(I,J,K)-GAMME(I,J,K-1)
             GOTO 110
100       GAMMA=GAMME(I,J,1)

110       CALL BIOT(X,Y,Z,GAMMA,RC,W)
          !WRITE(6,*)'ITERATION BSA M2 ',KITE
             DO 9 L=1,3
                SW(L)=SW(L)+W(L)
9            CONTINUE
      IF(BOOLPRINT.EQ..TRUE.)WRITE(8,9999)I,J,K,X(1),X(2),X(3),Y(1),
     -Y(2),Y(3),Z(1),Z(2),Z(3), SW(1),SW(2),SW(3)
     
99          IF(K .EQ. KMNET)GOTO 7
!C ************************************************************
!C           BEREGN. AF DE LANGSG$ENDE HVIRVL. INDFLYDELSE    *
!C ************************************************************
            DO 10 L=1,3
               X(L)=H1(I,J,K,L)
               Y(L)=H1(I,J,K+1,L)
10          CONTINUE
            IF (J .EQ. 1) GOTO 198
            IF (J .EQ. NOL1) GOTO 199
            GAMMA=GAMME(I,J-1,K)-GAMME(I,J,K)
            GOTO 200
199         GAMMA=GAMME(I,NOL,K)
            GOTO 200
198         GAMMA=-GAMME(I,1,K)
200         CALL BIOT(X,Y,Z,GAMMA,RC,W)
            !WRITE(6,*)'ITERATION BSA M1',KITE
            DO 11 L=1,3
               SW(L)=SW(L)+W(L)
11          CONTINUE
            IF (1.EQ.2)WRITE(9,9999)I,J,K,X(1),X(2),X(3),Y(1),Y(2),Y(3),
     -Z(1),Z(2),Z(3), SW(1),SW(2),SW(3)
7         CONTINUE
6       CONTINUE
!C ******************************************************
!C      HER MEDTAGES DE REST. LANGSG. HVIRVLER G$ENDE FRA
!C      K=2 TIL K=3 I TILF#LDET INDI=3                  *
!C ******************************************************
        IF (INDI1 .EQ. 1) GOTO 5
        DO 12 J=1,NOL1
           DO 13 L=1,3
             X(L)=H1(I,J,2,L)
             Y(L)=H1(I,J,3,L)
13         CONTINUE
           IF (J .EQ. 1) GOTO 298
           IF (J .EQ. NOL1) GOTO 299
            GAMMA=GAMME(I,J-1,2)-GAMME(I,J,2)
            GOTO 300
299         GAMMA=GAMME(I,NOL,2)
            GOTO 300
298         GAMMA=-GAMME(I,1,2)
300         CALL BIOT(X,Y,Z,GAMMA,RC,W)
            !WRITE(6,*)'ITERATION BSA ',KITE
            DO 14 L=1,3
               SW(L)=SW(L)+W(L)
14          CONTINUE
          IF (1.EQ.2)WRITE(10,9999)I,J,K,X(1),X(2),X(3),Y(1),Y(2),Y(3),
     -Z(1),Z(2),Z(3), SW(1),SW(2),SW(3)
12        CONTINUE
5      CONTINUE
9999  FORMAT(3(I3,X),9(F7.2,X),3(F10.3,X))
       RETURN
       END
      SUBROUTINE BSPD3
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       COMMON/BLAEST/VIND(300,3),UINF
       COMMON/SLIP/POINT(10,10,20,3),HAS(10,10,20,3),ITALX,ITALY,ITALZ
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       DIMENSION SW(3)
!C 
!C ***********************************************************************
!C      ROUTINEN FINDER DE LOKALE HASTIGHEDER I PLANERNE GIVET VED ITALX *
!C      ITALY OG ITALZ                                                   *
!C      OMKRING M@LLEN INDL#GGES EN KASSE MED KANTL#NGDERNE:             *
!C      X-RETNING......4*RMIDT                                           *
!C      Y-RETNING......3*RMIDT                                           *
!C      Z-RETNING......H0                                                *
!C      CENTRUM LIGGER I (0,0,H0/2)                                      *
!C ***********************************************************************
!C 
       IF (B .LT.-1000.) GOTO 10
       RMIDT=(A+B)*H0
       GOTO 20
10     RMIDT=A*H0
20     XMAX=2.*RMIDT
       YMAX=1.5*RMIDT
       XSTEP=2.*XMAX/REAL(ITALX-1)
       YSTEP=2.*YMAX/REAL(ITALY-1)
       ZSTEP=     H0/REAL(ITALZ-1)
       K=ITALZ/2
       K1=ITALZ-1
!C 
!C      KOORDINATERNE TIL PUNKTERNE UDREGNES,DE INDUCEREDE HAST. FINDES
!C 
       DO 1 I=1,ITALX
         DO 2 J=1,ITALY
           DO 3 M=1,K
             POINT(I,J,M,1)=(I-1)*XSTEP-XMAX
             POINT(I,J,M,2)=(J-1)*YSTEP-YMAX
             POINT(I,J,M,3)=(M-1)*ZSTEP
             HAS(I,J,M,1)=UINF
             HAS(I,J,M,2)=0.0
             HAS(I,J,M,3)=0.0
             CALL BSA(0,I,J,M,SW)
             DO 4 L=1,3
               HAS(I,J,M,L)=HAS(I,J,M,L)+SW(L)
4            CONTINUE
3          CONTINUE
2        CONTINUE
1      CONTINUE
       DO 6 I=1,ITALX
          DO 7 J=1,ITALY
             DO 8 M=K,K1
                   DO 9  L=1,2
                   POINT(I,J,M+1,L)=POINT(I,J,ITALZ-M,L)
                   HAS(I,J,M+1,L)=HAS(I,J,ITALZ-M,L)
9               CONTINUE
                POINT(I,J,M+1,3)=ZSTEP*M
                HAS(I,J,M+1,3)=-HAS(I,J,ITALZ-M,3)
8            CONTINUE
7         CONTINUE
6      CONTINUE
!C 
!C      UDSKRIFT AF HASTIGEDERNE I H@JDEN
!C      FORMATSPECIFIKATION T$LER H@JST ITALX=6 OG ITALX=4
!C 
       WRITE(6,100)
       WRITE(6,110)
       DO 5 M=1,ITALZ
         WRITE(6,120) POINT(1,1,M,3)
         IF (ITALX .EQ. 6)GOTO 200
         WRITE(6,180)
         WRITE(6,160) (POINT(I,1,M,1),I=1,ITALX)
         WRITE(6,170) (POINT(1,J,M,2),((HAS(I,J,M,L),L=1,3),I=1,ITALX),
     -J=1,ITALY)
       WRITE(6,160)
       GOTO 5
200   WRITE(6,150)
         WRITE(6,130) (POINT(I,1,M,1),I=1,ITALX)
         WRITE(6,140) (POINT(1,J,M,2),((HAS(I,J,M,L),L=1,3),I=1,ITALX),
     -J=1,ITALY)
       WRITE(6,150)
5      CONTINUE
100    FORMAT(1H1)
110    FORMAT(' ',35X,'*****TABELUDSKRIFT AF HASTIGHEDER*****')
120    FORMAT(' ','Z-KOORDINAT:',F10.2)
130    FORMAT(' ',6X,6(F20.2))
140    FORMAT((' ',F5.2,6(3F7.2)))
150    FORMAT(' ',125('-')/)
160    FORMAT(' ',7X,4(F21.2))
170    FORMAT((' ',F7.2,4(3F7.2)))
180    FORMAT(' ',91('-')/)
       RETURN
       END
!C 
!C       NAVN:CLCD
      SUBROUTINE CLCD(INB,JNOL,REY)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      COMMON/VAR/IT
      COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
      COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),CD(3,
     &299   )
      COMMON/INDDAT/TA1(2),TCL1(2),TCD1(2),
     -TA2(2),TCL2(2),TCD2(2),
     -TA3(2),TCL3(2),TCD3(2),
     -TA4(2),TCL4(2),TCD4(2),
     -TA5(2),TCL5(2),TCD5(2), 
     -TA1F(11),TCL1F(11),TCD1F(11),
     -TA1T(11),TCL1T(11),TCD1T(11),
     -TA2F(11),TCL2F(11),TCD2F(11),
     -TA2T(11),TCL2T(11),TCD2T(11),
     -TA3F(11),TCL3F(11),TCD3F(11),
     -TA3T(11),TCL3T(11),TCD3T(11),
     -TA4F(11),TCL4F(11),TCD4F(11),
     -TA4T(11),TCL4T(11),TCD4T(11),     
     -TA5F(11),TCL5F(11),TCD5F(11), 
     -TA5T(11),TCL5T(11),TCD5T(11), 
     -TAH(12),TCLH(12),TCDH(12),
     -R1,R2,R3,R4,R5
      
      INTEGER INB,JNOL,I,J
!C 
       
       LOGICAL FREM
       DATA N1,N2,N3 /2,11,12/
!C ***********************************************************************
!C       ROUTINEN INTERPOLERER CL-CD V#RDIER SOM FUNKT. AF REYNOLDSTAL-  *
!C       LET.ALFAD ER OPDELT I TRE OMR$DER 1-2-3 SVARENDE TIL:           *
!C       1..........0-2 GRD                                              *
!C       2..........2-22 "                                               *
!C       3..........22-180 GRD                                           *
!C       DER ANVENDES SPEJLEDE V#RDIER FOR 180-360 GRD.                  *
!C       INTERP. MELLEM VINKLER:ROUTINE "INTA"                           *
!C         "       "    REY-TAL:   "    "INTR"                           *
!C ***********************************************************************
!C 
!C    THIS ROUTINE WORKS FOR SYMMETRICAL AIRFOILS ONLY AND INTERPOLATION
!C    OCCURS IN THE POSITIVE ALFA RANGE(INTA TAKES ABS(ALFA))
!C    CURRENTLY WITH IDEAL AIRFOIL;SEE COMMENT BELOW
!C 
!C  555 FORMAT(' ',E10.2,'ALFAD:',F10.5)
!C 
!C ***************************************************
!C  VED KALD AF ROUTINEN STYRER I,J DELS V#RDIEN FOR *
!C  ALFAF@R(HENVISNING TIL COMMON) OG DELS ELEMENTET *
!C  I ALFA(I,J)                                      *
!C ***************************************************
!C      INDFALDSVINKLER REGNES OM TIL GRADER
       I=INB
       J=JNOL
       ALFADF=ALFAF(I,J)*180./PI
       ALFAD=ALFA(I,J)*180./PI
       ALFAB=ABS(ALFAD)
       A=1.
       FREM=.FALSE.
       IF (ALFAD.GT.0.) GOTO 10
       A=-A
10     IF (ABS(ALFAD).GT.ABS(ALFADF))FREM=.TRUE.
       CALL CLCDIDEAL(ALFAD,CLL,CDD)
       GOTO 999
       
       IOM=1
       IF (ABS(ALFAD).GT.2.4) IOM=2
       IF (ABS(ALFAD).GT.22.4) IOM=3
       GOTO (100,200,300) ,IOM
100    NT=N1
       IF (REY .GT. R2) GOTO 30
       CALL AFINTA(ALFAB,NT,1,TA1,TCL1,TCD1,CL1,CD1)
       CALL AFINTA(ALFAB,NT,1,TA2,TCL2,TCD2,CL2,CD2)
       CALL AFINTREY(REY,R1,R2,CL1,CD1,CL2,CD2,CLL,CDD)
       GOTO 999
30     IF (REY .GT. R3) GOTO 40
       CALL AFINTA(ALFAB,NT,1,TA2,TCL2,TCD2,CL2,CD2)
       CALL AFINTA(ALFAB,NT,1,TA3,TCL3,TCD3,CL3,CD3)
       CALL AFINTREY(REY,R2,R3,CL2,CD2,CL3,CD3,CLL,CDD)
       GOTO 999
40     IF (REY .GT. R4) GOTO 45
       CALL AFINTA(ALFAB,NT,1,TA3,TCL3,TCD3,CL3,CD3)
       CALL AFINTA(ALFAB,NT,1,TA4,TCL4,TCD4,CL4,CD4)
       CALL AFINTREY(REY,R3,R4,CL3,CD3,CL4,CD4,CLL,CDD)
       GOTO 999
C 
C     INTERPOLATION BETWEEN R4 AND R5
C 
45    CALL AFINTA(ALFAB,NT,1,TA4,TCL4,TCD4,CL4,CD4)
      CALL AFINTA(ALFAB,NT,1,TA5,TCL5,TCD5,CL5,CD5)
      CALL AFINTREY(REY,R4,R5,CL4,CD4,CL5,CD5,CLL,CDD)
      GOTO 999
  
200    NT=N2
       IF (REY .GT.R2) GOTO 50
       IF (FREM) GOTO 51
       CALL AFINTA(ALFAB,NT,2,TA1T,TCL1T,TCD1T,CL1,CD1)
       CALL AFINTA(ALFAB,NT,2,TA2T,TCL2T,TCD2T,CL2,CD2)
       GOTO 91
51     CALL AFINTA(ALFAB,NT,2,TA1F,TCL1F,TCD1F,CL1,CD1)
       CALL AFINTA(ALFAB,NT,2,TA2F,TCL2F,TCD2F,CL2,CD2)
91     CALL AFINTREY(REY,R1,R2,CL1,CD1,CL2,CD2,CLL,CDD)
       GOTO 999
50     IF (REY .GT.R3) GOTO 60
       IF (FREM) GOTO 61
       CALL AFINTA(ALFAB,NT,2,TA2T,TCL2T,TCD2T,CL2,CD2)
       CALL AFINTA(ALFAB,NT,2,TA3T,TCL3T,TCD3T,CL3,CD3)
       GOTO 92
61     CALL AFINTA(ALFAB,NT,2,TA2F,TCL2F,TCD2F,CL2,CD2)
       CALL AFINTA(ALFAB,NT,2,TA3F,TCL3F,TCD3F,CL3,CD3)     
92     CALL AFINTREY(REY,R2,R3,CL2,CD2,CL3,CD3,CLL,CDD)
       GOTO 999
60     IF (REY .GT.R4) GOTO 70
       IF (FREM) GOTO 71
       CALL AFINTA(ALFAB,NT,2,TA3T,TCL3T,TCD3T,CL3,CD3)
       CALL AFINTA(ALFAB,NT,2,TA4T,TCL4T,TCD4T,CL4,CD4)
       GOTO 93
71     CALL AFINTA(ALFAB,NT,2,TA3F,TCL3F,TCD3F,CL3,CD3)
       CALL AFINTA(ALFAB,NT,2,TA4F,TCL4F,TCD4F,CL4,CD4)
93     CALL AFINTREY(REY,R3,R4,CL3,CD3,CL4,CD4,CLL,CDD)
       GOTO 999
70     IF (FREM) GOTO 81
       CALL AFINTA(ALFAB,NT,2,TA4T,TCL4T,TCD4T,CL4,CD4)
       CALL AFINTA(ALFAB,NT,2,TA5T,TCL5T,TCD5T,CL5,CD5)
       GOTO 94
81     CALL AFINTA(ALFAB,NT,2,TA4F,TCL4F,TCD4F,CL4,CD4)
       CALL AFINTA(ALFAB,NT,2,TA5F,TCL5F,TCD5F,CL5,CD5)
94     CALL AFINTREY(REY,R4,R5,CL4,CD4,CL5,CD5,CLL,CDD)
       GOTO 999
300    NT=N3
       CALL AFINTA(ALFAB,NT,3,TAH,TCLH,TCDH,CLL,CDD)
999    CONTINUE
       CL(I,J)=A*CLL
       CD(I,J)=CDD
      RETURN
      END
      
      SUBROUTINE CLCDIDEAL(ALFAD,CLL,CDD)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      REAL PI 
      PARAMETER (PI=3.1415926535897932384626433832795)
      REAL SINA,SIN2A,CLL,CDD,ALFAB,A
C
C     CALCULATES IDEAL POLAR BASED ON FLAT PLATE(HIGH AOA) AND THIN AIRFOIL THEORY
C
!C    CLCDI WAS UUNTIL 050217 A PART OF CLCD()
!C    NO HYSTERESIS;CHECK BY
!C    CL=1.017*SIN(2*ALFA), CD=0.0060+1.8*SIN(ALFA)**2
!C    IF ALFA.LT.11.5 DEG) CL=2 PI ALFA; CD=0.00060
!C
      ! SINA=SIN((ALFAD*PI/180.))
      ! IF(ABS(ALFAD).GT.18) THEN
      !     CLL=2*PI*SINA
      !     CDD=0.0060
      ! ELSE
      !     CLL=1.017*SINA
      !     CDD=0.0060+1.8*SINA*SINA
      !ENDIF

C     WORK FOR 0-180 DEG, ASSUMES SYMMENTRY      
      A=1.
      IF (ALFAD.GT.0.) GOTO 10
      A=-A
10    ALFAB =ABS(ALFAD)
      SINA =SIN((ALFAB*PI/180.))! ALFAB =ABS(ALFAD)
      SIN2A=SIN((2.*ALFAB*PI/180.))
 
C     CHANGE 23-10-2016 SHARTPER CONDITION CL-CD
 
      IF(ALFAB.LT.172.) THEN
          !|ALFA|<172 DEG
          IF(ALFAB.LT.16.) THEN
           CLL=2.*PI*SINA
           CDD=0.0060
          ELSE
           CLL=1.035*SIN2A
           CDD=0.0060+1.8*SINA*SINA
          ENDIF       
      ELSE
          !|ALFA|>=172 DEG
          CLL=-2.*PI*SINA
          CDD=0.0060
      ENDIF  
C     CL MAKS AND CD0 ARE REY DEPENDENT
      RETURN
      END
!C 
!C 
      SUBROUTINE FLYT
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
!C 
!C ***********************************************************************
!C      3-D                                                              *
!C      ROUTINEN FLYTTER HVIRVLERNES POSITION EFTER EN KVADRATISK FORMEL *
!C      HVOR V1 OG V2 INDG$R VED MIDLINGEN.RENUMMERERER SAMTLIGE HVIRVLER*
!C      V.H.A. RENUMK                                                    *
!C      H1(K) SVARER TIL K'S POSITION F@R FLYTNINGEN                     *
!C      H2(K)      "     "       "    EFTER  FLYTNINGEN F@R RENUMK       *
!C      EFTER S.R. RENUMK VIL H2(K) HEDDE H1(K+1)                        *
!C      V2 SVARER TIL HAST. AF KNUDERNE TIL TIDSPKT. T                   *
!C      V1 SVARER TIL HASTIGHEDEN AF KNUDERNE TIL TIDSPKT T-DT           *
!C ***********************************************************************
!C 
       COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
       COMMON/RENUM/H2(3,300,8000,3),V2(3,300,8000,3)
       COMMON/BLAEST/VIND(300,3),UINF
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
!C 
       TETA=IRUN*DTETA
       NOL1=NOL+1
      DO 1 K=3,KMNET
       DO 2 I=1,NB
         DO 3 J=1,NOL1
           DO 4 L=1,3
             H2(I,J,K,L)=H1(I,J,K,L)+(1.5*V2(I,J,K,L)-.5*V1(I,J,K,L))*DT
4          CONTINUE
3        CONTINUE
2      CONTINUE
1     CONTINUE
!C 
!C      1'TE HVIRVEL=GAMMEL BUNDEN HVIRVEL FLYTTES
!C 
       DO 8 I=1,NB
         DO 9 J=1,NOL1
           DO 10 L=1,3
             H2(I,J,2,L)=V2(I,J,2,L)*DT+H1(I,J,2,L)
10         CONTINUE
9        CONTINUE
8      CONTINUE
!C 
       CALL RENUMK
!C 
 
!C 
!C    THE VORTEX IS LOCATED IS C/4!
!C 
      ETA=(1.-HSTAR-0.25)*C
      XI=0.0*C
      ZETA=0.0*C
      ETA=0
       DO 5 I=1,NB
           T1=TETA+CRANK(I)
         DO 6 J=1,NOL1
             FIR=T1-FI0(J)
             ST1=SIN(T1)
             CT1=COS(T1)
             SF=SIN(FIR)
             CF=COS(FIR)
             SB=SIN(BETA(J))
             CB=COS(BETA(J))
           DO 7 L=1,3
             H1(I,J,2,L)=V2(I,J,1,L)*DT+H1(I,J,1,L)
             V1(I,J,2,L)=0.0
             V1(I,J,1,L)=V2(I,J,1,L)
7          CONTINUE
           H1(I,J,1,1)=-BLSNIT(1,J,2)*ST1
     &                                  -XI*SF*CB-ETA*CF-ZETA*SF*SB
          !C HANGE 07102016
           H1(I,J,1,2)= BLSNIT(1,J,2)*CT1
     /                                  -XI*CF*CB-ETA*SF-ZETA*CF*SB
           H1(I,J,1,3)= BLSNIT(1,J,3)-XI*SB+ZETA*CB
           
!C    CHANGE 23-10-2016
!C    CHANGE 03102016/070102016
6        CONTINUE
5      CONTINUE
       RETURN
       END
!C 
!C 
      SUBROUTINE FORCES
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
       COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),CD(3
     &,299)
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/LAST/FR(3,299,8000),FT(3,299,8000),FB(3,299,8000)
       COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)
!C 
!C ***********************************************************************
!C      FORCES BEREGNER TANGENTIAL-KRAFT                                 *
!C                       RADIAL   -  "                                   *
!C                       KRAFT I Z-AKSENS RETNING                        *
!C                       FN -KRAFT I BLADETS NORMALRETNING               *
!C                       FC -       "        KORDE    "                  *
!C     I C/4 BLADPOSITION ; ALFA ER BEREGNET I 3C/4                      *
!C     THE FI0(J) HAS TO BE DEFINED BY UPDATING FROM T TO T+DT           *
!C                                                                       *
!C ***********************************************************************
       DO 1 I=1,NB
         DO 2 J=1,NOL
           CD1=CD(I,J)
           CL1=CL(I,J)
C          IF (ABS(ALFA(I,J)) .GT. PI/2.) CL1=-CL(I,J) !OBS ÆNDRING 110216 NU I CLCD ROUTINE
           SINA=SIN(ALFA(I,J))
           COSA=COS(ALFA(I,J))
           FN=-.5*RO*DSPAN(J)*(UREL(I,J)**2)*C*(CL1*COSA+CD1*SINA)
           FC= .5*RO*DSPAN(J)*(UREL(I,J)**2)*C*(CL1*SINA-CD1*COSA)
           COSB=COS(BETA(J))
           SINB=SIN(BETA(J))
           SINFI0=SIN(FI0(J))
           COSFI0=COS(FI0(J))
           FR(I,J,IRUN)= COSFI0*COSB*FN+FC*SINFI0
           FT(I,J,IRUN)=-SINFI0*FN*COSB+COSFI0*FC
           FB(I,J,IRUN)=-SINB*FN
           ALFAF(I,J)=ALFA(I,J)
 2       CONTINUE
 1     CONTINUE
       RETURN
       END
!C 
!C       NAVN:NETHAS
      SUBROUTINE NETHAS
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
      
       COMMON/BLAEST/VIND(300,3),UINF
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/RENUM/H2(3,300,8000,3),V2(3,300,8000,3)
       DIMENSION SW(3)
!C 
!C ***********************************************************************
!C       NETHAS UDREGNER DE LOKALE HASTIGHEDER FOR ALLE HVIRVELPUNKTER I *
!C       SLIPSTROEMMEN VED KALD AF BSA OG OVERLEJRING MED FRISTROEMSHAS- *
!C       TIGHEDEN.                                                       *
!C                                                                       *
!C ***********************************************************************
!C 
       NOL1=NOL+1
       N=NOL/2+1
!C 
!C        LOKAL HASTIGHED I KNUDER I SLIPSTR@M
!C 
       DO 1 I=1,NB
         DO 2 J=1,N
            DO 3 K=1,KMNET
              CALL BSA(1,I,J,K,SW)
                DO 4 L=1,3
                  V2(I,J,K,L)=SW(L)+VIND(J,L)
  4             CONTINUE
  3         CONTINUE
!C 
!C 
  2      CONTINUE
  1     CONTINUE
!C 
!C      SPEJLING OMKRING MIDTERAKSEN MED INDEKS N
!C 
       DO 5 I=1,NB
         DO 6 J=N,NOL
           DO 7 K=1,KMNET
             DO 8 L=1,2
               V2(I,J+1,K,L)=V2(I,NOL1-J,K,L)
  8          CONTINUE
           V2(I,J+1,K,3)=-V2(I,NOL1-J,K,3)
  7        CONTINUE
  6      CONTINUE
  5    CONTINUE
       RETURN
       END
!C 
!C 
      SUBROUTINE PLOT(INS)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
!C  *************************************************
!C  *                                               *
!C  *     PLOTTE-ROUTINE                            *
!C  *     PLOTNING AF NETPUNKTER                    *
!C  *                                               *
!C  *************************************************
!C 
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       DIMENSION XY(240,2)
       DIMENSION NP(3)
       LOGICAL CH(3)/'+','*','0'/,CF(3)/'1','2','3'/
!C 
       DO 4 M=1,NB
          NP(M)=KMNET
  4    CONTINUE
       DO 3 INB=1,NB
        DO 1 J=1,KMNET
          DO 2 L=1,2
          XY(J+(INB-1)*KMNET,L)=H1(INB,INS,J,L)
  2       CONTINUE
  1     CONTINUE
  3    CONTINUE
!C 
       WRITE(6,10)
!C      CALL TITLES('NETPUNKTS-POSITIONER',20,'X',1,'Y',1)
!C      CALL FILLUP(+1,CF,3)
!C      CALL SVPLOT(NB,240,CH,NP,XY,129,55,IER)
       WRITE(6,11) IER
!C 
  10   FORMAT(1H1)
  11   FORMAT(' ','IER = ',I5)
       RETURN
       END
!C      NAVN:OPSTART
      SUBROUTINE START
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)       
       COMMON/PERTU/SWB(3,299,3)
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
       COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),CD(3
     & ,299)
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/BLAEST/VIND(300,3),UINF
       REAL DUMMY
!C 
!C ***********************************************************************
!C       OPSTART GIVER ET INDTRYK AF HVIRVELMOENSTRET BAG VED MOELLEN,   *
!C       NAAR KONTROLBLADET STAAR I TETA=0 GRADER.HVER HVIRVEL HAR EN    *
!C       STYRKE SVARENDE TIL,AT INDFLYDELSEN AF DE ANDRE HVIRVLER KAN    *
!C       NEGLIGERES.DEN TOTALE INDFLYDELSE AF SLIPSTROEMMEN PAA BLADET   *
!C       LAGRES I SWB.                                                   *
!C                                                                       *
!C ***********************************************************************
!C 
!C      INDUCERET HASTIGHED VED OPSTART LIG NULL
!C 
 
!C 
!C      DEN BUNDNE HVIRVEL ER LOKALISERET I C/4-PUNKTET I ET LOKALT KOOR-
!C      DINATSYSTEM SOM ER BESKREVET VED ELEMENT(SNIT)GRÆNSERNE MEN MED 
!C      OMDREJNINGSPUNKTET SOM ORIGO. I FREMTIDEN 
!C      SKAL DETTE FORMENTLIG ÆNDRES SÅLEDES AT BEREGINGSKNUDEN(CENTER 
!C      FOR BLADELEMENTET) ALTID ER
!C      ORIGO FOR LOKALE KOORDINATSYSTEM N-C-S. DA SNITTENE UDREGNES OG 
!C      EVENTUELLE MIDTPUNKTER SÆRSKILT GØR INGEN FORSKEL PÅ FORSIMPLINGEN
!C 
      DUMMY=FI0DOT
      XI=0.0*C
!C
!C     ETA=(1.-HSTAR-0.25)*C
!C     C/4 CHORD POINT AS CP
!C      
      ETA=(0.75-HSTAR)*C
      ETA=0.
      ZETA=0.0*C
      ETA=0.
      OPEN(11,FILE='HPOS.DAT',STATUS='OLD',IOSTAT=IO)
	    IF (IO .NE. 0) THEN
         WRITE(6,*) 'ERROR: Cannot open HPOS.DAT (IOSTAT=', IO, ')'
         STOP
       ENDIF
       NOL1=NOL+1
!C 
!C    ARRAY LADES OG OPBYGNING AF NET BAGUD FORETAGES
!C 
       DO 1 K=1,KMNET
         TETA=(1-K)*DTETA
         DO 2 I=1,NB
          T1=TETA+CRANK(I)
          CT=COS(T1)
	    ST=SIN(T1)
!C 
!C    RADIUS TIL BLADSNIT (BLSNIT) FRA ROUTIN BLAD
!C    HVIRVLEN ER LOKALIOSERET I C/4 PUNKTET PÅ KORDEN-28092016
!C    I OPSTART SPOLES FI0(J)(t) OGSÅ TILBAGE, DVS MED NEG TILVÆKST.:. -FI0(J)
!C 
           DO 3 J=1,NOL1
             FIR=T1+FI0(J) !'-' BLEVET TIL '+', SE OVENFOR
	     SF=SIN(FIR)
	     CF=COS(FIR) 
           CB=COS(BETA(J))
           SB=SIN(BETA(J))
             H1(I,J,K,1)=VIND(J,1)*(K-1)*DT-BLSNIT(1,J,2)*ST
     /                      -XI*SF*CB-ETA*CF-ZETA*SF*SB
             H1(I,J,K,2)=BLSNIT(1,J,2)*CT
     /                      +XI*CF*CB-ETA*SF+ZETA*CF*SB        
             H1(I,J,K,3)=BLSNIT(1,J,3)
     /                      -XI*SB+ZETA*CB        
             IF ((J.EQ.NOL/2).AND. (I.EQ.2))WRITE(11,999)I,J,K,TETA,
     &        H1(I,J,K,1),H1(I,J,K,2),H1(I,J,K,3)
             DO 4 L=1,3
               V1(I,J,K,L)=VIND(J,L)
   4         CONTINUE
   3       CONTINUE
   2     CONTINUE
         DO 7 I=1,NB
           DO 8 J=1,NOL
             DO 9 L=1,3
               SWB(I,J,L)=0.0
   9         CONTINUE
   8       CONTINUE
   7     CONTINUE
     
         CALL WIND(TETA)
         DO 5 I=1,NB
           DO 6 J=1,NOL
             REY=UREL(I,J)*C/ANY
             CALL CLCD(I,J,REY)
             GAMME(I,J,K)=.5*C*CL(I,J)*UREL(I,J)
             ALFAF(I,J)=ALFA(I,J)
!             WRITE(6,1000)I,J,K,TETA,UREL(I,J),ALFA(I,J),GAMME(I,J,K)
   6       CONTINUE 
   5     CONTINUE
   1   CONTINUE
999   FORMAT(3(I3,X),4(F8.3,X))
1000  FORMAT(3(I5,X),4(F10.3,2X))
      CLOSE(11)
       RETURN
       END
      SUBROUTINE AFINTREY(REY,REN,REO,CLN,CDN,CLO,CDO,CL,CD)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
!C 
!C ***********************************************************************
!C      INDEKS I DE FORMELLE PARAMETRE:N......."NEDRE V#RDI"             *
!C                                     O......."@VRE  V#RDI"             *
!C      INTERPOLERER MELLEM REYNOLDSTAL FOR ET GIVET ALFAD               *
!C      FOR REYNOLDSTAL>R4 BIBEHOLDES CLO OG CDN                         *
!C ***********************************************************************
       CL=CLO
       CD=CDN
!C       IF (REY.GT.40E+09) RETURN
       CL=(CLO-CLN)*(REY-REN)/(REO-REN)+CLN
       CD=(CDO-CDN)*(REY-REN)/(REO-REN)+CDN
       RETURN
       END
!C 
!C      NAVN:RENUMMER
      SUBROUTINE RENUMK
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
!C 
!C ***********************************************************************
!C      ROUTINEN RENUMMERER ARRAYS M.H.T."K" OG GEMMER DE LIGE F@R       *
!C      UDREGNEDE HASTIGHEDER OG POSITIONER TIL BRUG VED DE EFER-        *
!C      F@LGENDE OPERATIONER I DET N#STE TIDSSTEP.DEN BUNDNE HVIR-       *
!C      VEL GEMMES P$ F@RSTE POSITION I SLIPSTR@MMEN(:GAMME(2))          *
!C ***********************************************************************
!C 
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/RENUM/H2(3,300,8000,3),V2(3,300,8000,3)
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
!C 
       NOL1=NOL+1
       KM=KMNET-2
!C 
       DO 1 I=1,NB
         DO 2 J=1,NOL1
           DO 3 N=1,KM
             K=KMNET-N
             K1=K+1
             DO 4 L=1,3
               H1(I,J,K1,L)=H2(I,J,K,L)
               V1(I,J,K1,L)=V2(I,J,K,L)
    4        CONTINUE
             GAMME(I,J,K1)=GAMME(I,J,K)
    3      CONTINUE
         GAMME(I,J,2)=GAMME(I,J,1)
    2    CONTINUE
    1  CONTINUE
       RETURN
       END
!C      NAVN:VORTEX+
       SUBROUTINE VORTEX(ARES)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/NET/H1(3,300,8000,3),V1(3,300,8000,3),GAMME(3,300,8000),
     &  KMNET
       COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),CD(3
     &  ,299)
       COMMON/PERTU/SWB(3,299,3)
       
       DIMENSION WB(3,299,3),SWSLIP(3,299,3),GAMMET(3,299)
       DIMENSION X(3),Y(3),Z(3),W(3)
       COMMON/VAR/IT
       COMMON/STYR/IRUNS,IBSNIT,INOL,KITE
       DIMENSION WSLIP(3)
       
!C 
!C ***********************************************************************
!C      VORTEX BEREGNER DEN BUNDNE HVIRVELSTYRKE P$ BLADET V.H.A.BSA OG  *
!C      BS.GAMMEB M$ BESTEMMES ITERATIVT VED AT G#TTE P$ EN L[SNING,SOM  *
!C      DEN @VRIGE SLIPSTR@M INDUCERER P$ BLADET.DETTE UDF@RES V.H.A.    *
!C      BSA.DEN SAMLEDE INDUCEREDE HASTIGHED ER DA L@SNINGEN FRA DEN @VR.*
!C      SLIPSTR@M PLUS L@SNINGEN GIVET VED DEN AFKASTEDE,SOM BS BESTEMMER*
!C      SYMMETRIEN UDNYTTES                                              *
!C ***********************************************************************
!C    |   |   |   |   4   |   5   |.....|NOL-1| ELEMENTS
!C    T   T   T   T       T       T     T     T K=1?(SLÅ DET OP)
!C    1   2   3   4       5       6......     NOL SNIT
!C 
!C     SYMMETRIEN ER IKKE LÆNGERE OPRETHOLDT 11-11-14
!C     SYMMETRIEN ER OPRETHOLDT I DENNE VERSION 280116 SE NEDE MED SYMMETRI VED! 
!C     SNIT NUMMER N1=NOL/2+1
 
       TETA=IRUN*DTETA
       NOL1=NOL+1
       N=NOL/2    ! HER BLIVER FOR NOL=28 N=14 OG DET SIDSTE SNIT I SYMMETRIEN N1=15
       N1=N+1
       IT=0
       !WRITE(*,*)'TETA',TETA*180/PI,' deg ', 'IR: ', IR

       DO 1 INB=1,NB
       DO 2 INS=1,N1 !->DO 2 INS=1,NOL1 
!C        DO 2 INS=1,NOL1
!C 
!C        DE INDUCEREDE HASTIGHEDER FINDES I ALLE BLADSNIT
!C        HER GÅR DET GALT
!C 
           CALL BSA(3,INB,INS,1,WSLIP)

           DO 3 L=1,3
             SWSLIP(INB,INS,L)=WSLIP(L)
    3      CONTINUE
    2    CONTINUE
    1  CONTINUE
!       GOTO 54 ! CHANGE
!      DO 51 INS=N1,NOL->DO 51 INS=1,NOL 
       DO 51 INB=1,NB
         DO 52 INS=N1,NOL
           DO 53 L=1,2
             SWSLIP(INB,INS+1,L)=SWSLIP(INB,NOL1-INS,L)
   53      CONTINUE
            SWSLIP(INB,INS+1,3)=-SWSLIP(INB,NOL1-INS,3)
   52    CONTINUE
   51 CONTINUE
   54 CONTINUE  
!C 
!C        DE INDUCEREDE HASTIGHEDER FINDES I BEREGNINGSPUNKTERNE
!C 
       DO 29 INB=1,NB
        DO 30 INS=1,NOL
          DO 31 L=1,3
            SWSLIP(INB,INS,L)=.5*(SWSLIP(INB,INS+1,L)+SWSLIP(INB,INS,L))
            SWB(INB,INS,L)=SWSLIP(INB,INS,L)
   31     CONTINUE
!C 
!C          G#T P$ GAMMABUNDEN=GAMMAB FOR EN PERIODE BAGUD
!C 
           GAMME(INB,INS,1)=GAMME(INB,INS,NPSI)
   30    CONTINUE
   29   CONTINUE
       GOTO 100
  200  DO 4 INB=1,NB
         DO 5 INS=1,N
         !DO 5 INS=1,NOL
           DO 6 L=1,3
             WB(INB,INS,L)=0.0!C HANGE REAL*8->4
!C 
!C            KOORDINATERNE TIL BEREGNINGSPUNKTERNE BESTEMMES
!C 
             Z(L)=.5*(H1(INB,INS,1,L)+H1(INB,INS+1,1,L))
    6      CONTINUE
           DO 7 I=1,NB
!C 
!C          DE BUNDNE(MINUS DEN P$G#LDENDE),AFKASTEDE OG LANGSG. MEDTAGES
!C 
             DO 8 J=1,NOL1
             IF(J.EQ.NOL1) GOTO 101
             DO 9 K=1,2
               DO 10 L=1,3
                 X(L)=H1(I,J,K,L)
                 Y(L)=H1(I,J+1,K,L)
   10          CONTINUE
               IF(K.EQ.1) GOTO 90
               GAMMA=GAMME(I,J,K)-GAMME(I,J,K-1)
               GOTO 91
   90        GAMMA=GAMME(I,J,1)
   91        CALL BIOT(X,Y,Z,GAMMA,RC,W)
             !WRITE(6,*)'ITERATION VORTEX(ARES)M1 ',KITE
               DO 11 L=1,3
                 WB(INB,INS,L)=WB(INB,INS,L)+W(L)
   11          CONTINUE
    9        CONTINUE
             DO 40 L=1,3
               X(L)=H1(I,J,1,L)
               Y(L)=H1(I,J,2,L)
   40        CONTINUE
             IF(J.EQ.1) GOTO 80
             GAMMA=GAMME(I,J-1,1)-GAMME(I,J,1)
             GOTO 81
  101        GAMMA=GAMME(I,NOL,1)
             DO 50 L=1,3
               X(L)=H1(I,NOL1,1,L)
               Y(L)=H1(I,NOL1,2,L)
   50        CONTINUE
             GOTO 81
   80        GAMMA=-GAMME(I,1,1)
   81        CALL BIOT(X,Y,Z,GAMMA,RC,W)
             !WRITE(6,*)'ITERATION VORTEX(ARES) ',KITE
             DO 12 L=1,3
               WB(INB,INS,L)=WB(INB,INS,L)+W(L)
   12        CONTINUE
    8      CONTINUE
    7   CONTINUE
         DO 13 L=1,3
           SWB(INB,INS,L)=SWSLIP(INB,INS,L)+WB(INB,INS,L)
   13    CONTINUE
    5  CONTINUE
    4  CONTINUE
       !GOTO 100 !INSERTED TO AVOID MIRRORING OF DATA
       DO 60 INB=1,NB
        DO 61 INS=N1,NOL
          DO 62 L=1,2
            SWB(INB,INS,L)=SWB(INB,NOL1-INS,L)
   62     CONTINUE
          SWB(INB,INS,3)=-SWB(INB,NOL1-INS,3)
   61   CONTINUE
   60  CONTINUE
  100  CALL WIND(TETA)
       
!C 
!C     L@SNINGSG#T FINDES,DEN FOREG$ENDE L[SNING GEMMES.DER TESTES
!C     VED PERIODICITETEN P$ DEN ST@RSTE RELATIVE AFVIGELSE AF DEN
!C     BUNDNE CIRKULATION
!C 
       DO 14 INB=1,NB
        DO 15 INS=1,N!C  N->NOL CHANGED
         !DO 15 INS=1,NOL
           GAMMET(INB,INS)=GAMME(INB,INS,1)
           REY=UREL(INB,INS)*C/ANY
!C           IF (UREL(INB,INS).GT.80.) WRITE(6,*)'UREL GT 80 M/S', 
!C     -UREL(INB,INS),TETA,INB,INS
           CALL CLCD(INB,INS,REY)
            GAMME(INB,INS,1)=.5*C*CL(INB,INS)*UREL(INB,INS)
   15    CONTINUE
   14  CONTINUE
!C       GOTO 72 !MIRROR
       DO 70 INB=1,NB
         DO 71 INS=N1,NOL
           GAMMET(INB,INS)=GAMMET(INB,NOL1-INS)
           GAMME(INB,INS,1)=GAMME(INB,NOL1-INS,1)
           CL(INB,INS)=CL(INB,NOL1-INS)
           CD(INB,INS)=CD(INB,NOL1-INS)
!C          WRITE(6,*) CL(INB,INS),CD(INB,INS),GAMME(INB,INS,1)
   71    CONTINUE
   70  CONTINUE
   72  CONTINUE     
       IT=IT+1
       GMAX=0.0
       GMIX=0.0
       DO 16 INB=1,NB
         DO 17 INS=1,N
           GMAX=AMAX1(ABS(GAMME(INB,INS,1)),GMAX)
           GMIX=AMAX1(ABS(GAMME(INB,INS,1)-GAMMET(INB,INS)),GMIX)
!C      IF(INS.EQ.14)WRITE(6,*) IT,INS,GMAX,GMIX,(GMIX/GMAX)
!C      WRITE(6,"(3(F10.3,X),3(I5,X))")ALFA(INB,INS)*180./PI,
!C     &     GAMME(INB,INS,1),GAMMET(INB,INS),IT,INB,INS
   17    CONTINUE
   16  CONTINUE
!C
!C     THERE IS A PROBLEM IN IF GAMMA IS VERY HIGH/FAR FROM SOLUTION. THIS GIVES A HIGH GMAX AND GIGH GMIX, 
!C     AND A GG THAT IS NUMERICALLY STABLE, BUT UNREAL!
!C

       IF (GMAX) 18,18,19
   19  GG=ABS(GMIX/GMAX)
       IF(GG.LT.EPS1) GOTO 18
       IF(IT.GT.9999)GOTO 300
       DO 20 I=1,NB
       DO 21 J=1,NOL
         GAMME(I,J,1)=ARES*GAMME(I,J,1)+(1.-ARES)*GAMMET(I,J)
   21    CONTINUE
   20  CONTINUE
       GOTO 200
   18  RETURN
  300  WRITE(6,400)
       WRITE(6,*)'   ALFA     UREL        CL      CD      BLADE     NOL'
       DO 41 I=1,NB
       DO 42 J=1,NOL
         IF (LARGEROTOR) THEN 
          WRITE(6,*)ALFA(I,J)*180./PI,UREL(I,J),CL(I,J),CD(I,J),I,J
         ELSE 
          WRITE(6,401)ALFA(I,J)*180./PI,UREL(I,J),CL(I,J),CD(I,J),I,J
         ENDIF
   42  CONTINUE
   41  CONTINUE   
  400  FORMAT(' ',/' FOR MANGE ITERATIONER(999)'/,' -----'/)
  401  FORMAT(2(F10.2),2X,F10.2,F10.4,2X,2(I10))
       RETURN
       END
!C 
!C       NAVN:WIND
       SUBROUTINE WIND(TETA)
      IMPLICIT INTEGER (I-N), REAL (A-H, O-Z)
!C 
!C ***********************************************************************
!C      ROUTINEN UDREGNER VINDENS HASTIGHED MOD BLADET,SAMT INDFALDS-    *
!C      VINKEL.SWB ER DOWNWASHVEKTOR.                                    *
!C ***********************************************************************
!C 
       COMMON/PAR/PI,RO,ANY,OMEGA,DTETA,C,EPS1,DT,RC,HSTAR,FI0DOT,IRUN,
     & IR,NPSI
       COMMON/SPAN/DSPAN(299),BETA(299),FI0(299)
      COMMON/ROTOR/CRANK(3),BLSNIT(3,300,3),NB,NOL,H0,A,B,BSAF,RS(300,2)
       COMMON/BLAEST/VIND(300,3),UINF
       COMMON/PERTU/SWB(3,299,3)
       COMMON/VELOCI/UREL(3,299),ALFA(3,299),ALFAF(3,299),CL(3,299),CD(3
     &  ,299)
       COMMON/LWRITE/BOOLPRINT
       DIMENSION UVEK(3,299,3),ULOC(3,299,3)
       REAL AA,ETA,XI,ZETA
!C 
!C    CP ON CHORD LINE(C/4 AND 3C/4)-BOTH WITH XI=0 AND ZETA=0
!C    FIRST LOOP AT C/4 AND 2ND LOOP AT 3C/4
!C    DEFINITION OF TURNING POINT: DISTANCE H*=h/c APART CALCLULATED FROM TE
!C    CHORD DISTANCE X FRO ORIGO TO CP(C/4):X=1-h/c-1/4
!C 
      XI=0.0*C
      FIDOT=OMEGA-FI0DOT!OMEGA NOT NESSERARLY CONSTANT?
!C
!C    ETA=C*(1.0-HSTAR-0.25)
!C
      ETA=C*(0.75-HSTAR)
      ZETA=0.0*C
      ETA=0.0
      DO 1 I=1,NB
         TETA1=TETA+CRANK(I)
         ST1=SIN(TETA1)
         CT1=COS(TETA1)
         DO 2 J=1,NOL
           FI=TETA1-FI0(J)
           RZ=.5*(BLSNIT(1,J,2)+BLSNIT(1,J+1,2))
           CF=COS(FI)
	     SF=SIN(FI)
	     CB=COS(BETA(J))
	     SB=SIN(BETA(J))
!C 
!C    RELATIV HASTIGHED I GLOBALT KOORDINATSYSTEM
!C    VIND ER GIVET I SNITTENE-IKKE I BEREGNINGSPUNKTET(OBS VIND=CONST): 
!C    VIND IKKE KONSTANT-RET DA IND EMD (VIND(J,1)+VIND(J+1,1))/2.
!C 
          UVEK(I,J,1)=VIND(J,1)+SWB(I,J,1)+RZ*OMEGA*CT1 
     /                             -FIDOT*(XI*CF*CB-ETA*SF+ZETA*CF*SB)
          UVEK(I,J,2)=          SWB(I,J,2)+RZ*OMEGA*ST1
     /                             -FIDOT*(XI*SF*CB+ETA*CF+ZETA*SF*SB)
          UVEK(I,J,3)=            SWB(I,J,3)

!C 
!C     RELATIV HASTIGHED LOKALT I C/4 PUNKT
!C 
           ULOC(I,J,1)=-UVEK(I,J,1)*SF*CB
     /                 +UVEK(I,J,2)*CF*CB
     /                 -UVEK(I,J,3)*SB
           ULOC(I,J,2)=-UVEK(I,J,1)*CF-UVEK(I,J,2)*SF
!C     WRITE(6,*)I,J,FI,ULOC(I,J,1),ULOC(I,J,2)
!C
!C    RELATIV HASTIGHED P$ BLADET I 1/4-KORDE PUNKT
!C
           UREL(I,J)=0.0
           DO 3 L=1,2
             UREL(I,J)=UREL(I,J)+ULOC(I,J,L)*ULOC(I,J,L)
    3      CONTINUE
           UREL(I,J)=SQRT(UREL(I,J))
!C
!C    FORTEGN P$ INDFALDSVINKEL
!C
!C   BEREGNING AF RELATIV VIND I 1/4-KORDE PUNKT(SAMMEN MED KRÆFTER) OG AOA I 3/4-KORDE PUNKT
!C           T1= -ULOC(I,J,1)
!C           T2= -ULOC(I,J,2)
!C
!C    INDFALDSVINKEL
!C
!C   BEREGNING AF RELATIV VIND I 1/4-KORDE PUNKT(SAMMEN MED KRÆFTER) OG AOA I 3/4-KORDE PUNKT
!C           ALFA(I,J)=ATAN2(T1,T2)
    2    CONTINUE
    1  CONTINUE
      DO I=1,NB
          DO J=1,NOL
              DO K=1,3
              UVEK(I,J,K)=0.0
              END DO
          END DO
      END DO    
              
!C
!C SECOND LOOP FOR DETERMINING ALFA AT CP=3C/4
!C

!C      ETA=C*(1.0-HSTAR-0.75)
        ETA=C*(0.25-HSTAR)
        ETA=0.0
       DO 11 I=1,NB
         TETA1=TETA+CRANK(I)
         ST1=SIN(TETA1)
         CT1=COS(TETA1)
         DO 12 J=1,NOL
           FI=TETA1-FI0(J)
           RZ=.5*(BLSNIT(1,J,2)+BLSNIT(1,J+1,2))
           CF=COS(FI)
	     SF=SIN(FI)
	     CB=COS(BETA(J))
	     SB=SIN(BETA(J))

!C         FI0DOT=(FI(J)-FIOLD(J))/DT !SKAL SENERE BESTEMMES MERE INDGÅENDE, F.EKS FIPRIK
!C 
!C    RELATIV HASTIGHED I GLOBALT KOORDINATSYSTEM
!C    VIND ER GIVET I SNITTENE-IKKE I BEREGNINGSPUNKTET(OBS VIND=CONST): 
!C    VIND IKKE KONSTANT-RET DA IND EMD (VIND(J,1)+VIND(J+1,1))/2.
!C 
          UVEK(I,J,1)=VIND(J,1)+SWB(I,J,1)+RZ*OMEGA*CT1 
     /                    -FIDOT*(XI*CF*CB-ETA*SF+ZETA*CF*SB)
          UVEK(I,J,2)=          SWB(I,J,2)+RZ*OMEGA*ST1
     /                    -FIDOT*(XI*SF*CB+ETA*CF+ZETA*SF*SB)
          UVEK(I,J,3)=          SWB(I,J,3)

!C 
!C     RELATIV HASTIGHED LOKALT KOORDINATSYSTEM
!C 
           ULOC(I,J,1)=-UVEK(I,J,1)*SF*CB
     /                 +UVEK(I,J,2)*CF*CB
     /                 -UVEK(I,J,3)*SB
           ULOC(I,J,2)=-UVEK(I,J,1)*CF-UVEK(I,J,2)*SF
!C
!C    FORTEGN P$ INDFALDSVINKEL
!C
!C   BEREGNING AF RELATIV VIND I 1/4-KORDE PUNKT(SAMMEN MED KRÆFTER) OG AOA I 3/4-KORDE PUNKT
           T1= -ULOC(I,J,1)
           T2= -ULOC(I,J,2)
!C    ULOC(I,J,1)=U(1);ULOC(1,J,2)=U(2); 
!C    U.(-C)=|U||-C| COS(ALFA)=>U(1)*0+U(2)*(-C)=|U||-C| COS(ALFA)
!C    INDFALDSVINKEL ALFA
!C
!C   BEREGNING AF RELATIV VIND I 1/4-KORDE PUNKT(SAMMEN MED KRÆFTER) OG AOA I 3/4-KORDE PUNKT
           ALFA(I,J)=ATAN2(T1,T2) 
         !      IF( ABS( ULOC(I,J,2)*(-1)/SQRT(
         !/      ULOC(I,J,2)*ULOC(I,J,2)+ULOC(I,J,1)*ULOC(I,J,1))
         !/      -COS(ALFA(I,J))).GT.0.)THEN 
         !      WRITE(6,*)' OH-OH'
         !      ENDIF
   12    CONTINUE
   11  CONTINUE       
       RETURN
       END
