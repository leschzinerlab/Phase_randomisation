C  makestack_HRnoise.for   **********************************************
C									*
C	  This program will calculate 2-dimensional FFT's from a stack 	*
C	of particles, replace the high resolution Fourier components	*
C	with the transform of either noise from a matching stack of 	*
C	background areas from the same micrographs, or simply random 	*
C	phases with the same high resolution amplitudes from the same 	*
C	particle stack, and write out the altered image stack. 							*
C									*
C	  All transforms are done using Lynn ten Eyck's subroutines.	*
C	These allow arbitrary-sized images having a LARGEST PRIME	*
C	factor of 19!!.							*
C									*
C									*
C     Input parameters are required.					*
C     Card 1:	XMAG, DSTEP, RESOLUTION, LBACK (3F10.1,L) 		*
C     		describes magnification, pixel size (microns) and 	*
C		the desired resolution beyond which the Fourier 	*
C		components of each particle transform are replaced 	*
C		with either the transform of matching backgrounds or	*
C		with randomised particle phases.  If LBACK.eq.FALSE, 	*
C		then use randomised phases, not a background stack.	*
C									*
C	Logical I/O assignments are:					*
C									*
C	IN_PART			input particle stack			*
C	IN_BACK			input matching background stack		*
*				(only read if LBACK.eq.TRUE		*
C	OUT			output particles with HR noise		*
C									*
C									*
C	Version   1.00	7.7.2011	RH				*
C									*
C************************************************************************
C  make dimension 16016000 to allow up to 2000x2000 particle boxes 
        INTEGER ARRMXSIZ
      	PARAMETER (ARRMXSIZ=16016000)
        COMMON//NX,NY,NZ
	DIMENSION ARRAY(ARRMXSIZ),ARRAYB(ARRMXSIZ),ARRAYOUT(ARRMXSIZ)
      	COMPLEX CRAY(ARRMXSIZ/2),CRAYB(ARRMXSIZ/2),CRAYOUT(ARRMXSIZ/2)
	DIMENSION TITLE(20)
        DIMENSION NXYZP(3),MXYZP(3),NXYZF(3),NXYZST(3)
        DIMENSION NXYZB(3),MXYZB(3)
	CHARACTER DAT*24
	LOGICAL LBACK
	CHARACTER*80 TMPTITLE
	EQUIVALENCE (TMPTITLE,TITLE)
C
	EQUIVALENCE (NX,NXYZP),(ARRAY,CRAY),(ARRAYB,CRAYB)
        EQUIVALENCE (ARRAYOUT,CRAYOUT)
	DATA ZERO/0.0/, NXYZST/3*0/
        DATA IFOR/0/,IBAK/1/
C
	WRITE(6,1000)
1000	FORMAT(//' makestack_HRnoise V1.00 (7.7.11)',//)
        READ(*,*) XMAG, DSTEP, RESOLUTION, LBACK
        WRITE(*,*) ' XMAG, DSTEP, RESOLUTION, LBACK=',
     .       XMAG,DSTEP,RESOLUTION,LBACK
C
	CALL IMOPEN(1,'IN_PART','RO')
	IF(LBACK) CALL IMOPEN(2,'IN_BACK','RO')
        CALL IMOPEN(3,'OUT','NEW')
	CALL FDATE(DAT)
C
C   Read input headers
C
	CALL IRDHDR(1,NXYZP,MXYZP,MODE,DMINP,DMAXP,DMEANP)
	  IF (MODE .GE. 3) STOP'Program uses images not transforms'
          IF(2*((NX/2)+1)*NY.GT.ARRMXSIZ) STOP'ARRMXSIZ too small'
        IF(LBACK) THEN
          CALL IRDHDR(2,NXYZB,MXYZB,MODEB,DMINB,DMAXB,DMEANB)
          IF(MODE.NE.MODEB) 
     .    STOP' MODE for particle and background stacks must be same'
          IF(NXYZB(1).NE.NXYZP(1)) GOTO 98
          IF(NXYZB(2).NE.NXYZP(2)) GOTO 98
          IF(NXYZB(3).NE.NXYZP(3)) GOTO 98
        ENDIF
        PIXEL = DSTEP*10000.0/XMAG
        RESRAD = PIXEL*NX/RESOLUTION
        WRITE(*,*)' Pixel radius for substitution=',RESRAD
	CALL ITRHDR(3,1)
C   The following line should be replaced by a more sophisticated
C   calculation, once the mechanism of memory allocation is worked out.
	MAXSIZ = ARRMXSIZ
	NY2 = NY/2
	NY21 = NY2 + 1
	NZM1 = NZ - 1
	TMIN =  1.E10
	TMAX = -1.E10
	TMEAN = 0.0
C
        NXR = NX
C
	IF (NZ .GT. 1) WRITE(6,1200) NZ
1200	FORMAT(//' Each of the ',I5,' sections are SEPARATELY ',
     .	'processed!!!!'//)
C
C   Here for forward transform
C
	NXM1 = NX - 1
	NYM1 = NY - 1
	NX2 = NX/2
	NX21 = NX2 + 1
	NXP2 = NX + 2
	NXYZF(1) = NX21
	NXYZF(2) = NY
	NXYZF(3) = NZ
C  keep same mode and header in output file as on input particle file
C
        WRITE(*,*) RESOLUTION,DAT(5:24)
	IF(LBACK)THEN
           WRITE(TMPTITLE,1500) RESOLUTION,DAT(5:24)
        ELSE
           WRITE(TMPTITLE,1501) RESOLUTION,DAT(5:24)
        ENDIF
1500	FORMAT(' makestack_HRnoise: data above',
     .    F6.1,'A replaced by noise',5X,A20)
 1501   FORMAT(' makestack_HRnoise: data above',
     .    F6.1,'A phases randomised',5X,A20)
	CALL IWRHDR(3,TITLE,1,ZERO,ZERO,ZERO)
C
C  Loop over all sections & write out the HR noise stack
C
	DO 100 ISEC = 0,NZM1
      	    CALL IMPOSN(1,ISEC,0)
	    CALL IRDPAS(1,ARRAY,NXP2,NY,0,NXM1,0,NYM1,*99)
	    CALL TODFFT(ARRAY,NX,NY,IFOR)
            IF(LBACK) THEN
               CALL IMPOSN(2,ISEC,0)
               CALL IRDPAS(2,ARRAYB,NXP2,NY,0,NXM1,0,NYM1,*99)
               CALL TODFFT(ARRAYB,NX,NY,IFOR)
            ENDIF
C  here for substitution of HR noise
            CALL HRNOISE(CRAY,CRAYB,CRAYOUT,
     .           NX21,NY,NY2,NYM1,LBACK,RESRAD)
            CALL TODFFT(ARRAYOUT,NXR,NY,IBAK)
	    CALL IWRPAS(3,ARRAYOUT,NXP2,NY,0,NXM1,0,NYM1)
	    CALL ICLDEN(ARRAYOUT,NXP2,NY,1,NX,1,NY,DMIN,DMAX,DMEAN)
	  IF (DMIN .LT. TMIN) TMIN = DMIN
	  IF (DMAX .GT. TMAX) TMAX = DMAX
	  TMEAN = TMEAN + DMEAN
	  IF (NZ .GT. 1) WRITE(6,1600) ISEC,DMIN,DMAX,DMEAN
100	CONTINUE
1600	FORMAT('Min,Max,Mean values for section ',I5,' are: ',3G13.5)
90	TMEAN = TMEAN/NZ
	WRITE(6,1800) TMIN,TMAX,TMEAN
1800	FORMAT(/,' Overall Min,Max,Mean values are: ',3G13.5)
	CALL IWRHDR(3,TITLE,-1,TMIN,TMAX,TMEAN)
	CALL IMCLOSE(1)
	IF(LBACK) CALL IMCLOSE(2)
        CALL IMCLOSE(3)
	CALL EXIT
C
99	STOP 'END-OF-FILE ERROR ON READ'
98      STOP'Particle and Background sizes not equal'
	END
C**************************************************************************************
      SUBROUTINE HRNOISE(CRAY,CRAYB,CRAYOUT,
     .     NX21,NY,NY2,NYM1,LBACK,RESRAD)
      INTEGER ARRMXSIZ
      PARAMETER (ARRMXSIZ=16016000)
      COMPLEX CRAY(ARRMXSIZ/2),CRAYB(ARRMXSIZ/2),CRAYOUT(ARRMXSIZ/2)
      LOGICAL LBACK,LFIRST
      DATA LFIRST/.TRUE./
C
      IF(RESRAD.GE.NX21.AND.LFIRST) THEN
         WRITE(*,*)'Resolution>Nyquist, no noise substituted'
         LFIRST=.FALSE.
      ENDIF
C
      DO 100 I=1,NX21
        X=I-1
        DO 200 J=NY2,NYM1
          INDEX = I + NX21*J
          Y=J-NY
          RAD=SQRT(X**2 + Y**2)
          IF(RAD.LE.RESRAD) THEN
             CRAYOUT(INDEX)=CRAY(INDEX)
          ELSE
             IF(LBACK) THEN 
                CRAYOUT(INDEX)=CRAYB(INDEX)
             ELSE
                CALL RANDOMISE(CRAY(INDEX))
                CRAYOUT(INDEX)=CRAY(INDEX)
             ENDIF
          ENDIF
200     CONTINUE
        DO 300 J=0,NY2-1
          INDEX = I + NX21*J
          Y=J
          RAD=SQRT(X**2 + Y**2)
          IF(RAD.LE.RESRAD) THEN
             CRAYOUT(INDEX)=CRAY(INDEX)
          ELSE
             IF(LBACK) THEN 
                CRAYOUT(INDEX)=CRAYB(INDEX)
             ELSE
                CALL RANDOMISE(CRAY(INDEX))
                CRAYOUT(INDEX)=CRAY(INDEX)
             ENDIF
          ENDIF
300     CONTINUE
100   CONTINUE
      RETURN
      END
C*************************************************************************************
      SUBROUTINE RANDOMISE(CRAY)
      COMPLEX CRAY,C(1)
      REAL A(2)
      EQUIVALENCE (A,C)
        C(1)=CRAY 
        AMP = SQRT(A(1)**2 + A(2)**2)
        ANG = ATAN2(A(2),A(1))
        CALL RANDOM_NUMBER(ANGRAND)
        ANGRAND = ANGRAND*2.0*3.1415926
C        write(*,*) 'ANGRAND=',ANGRAND
        A(1)=AMP*COS(ANGRAND)
        A(2)=AMP*SIN(ANGRAND)
        CRAY=C(1)
      RETURN
      END
C*************************************************************************************
