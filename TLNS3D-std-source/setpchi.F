c------------------------------------------------------------------------------
c The TLNS3D code was developed to solve Reynolds-averaged Navier-Stokes
c Equations to simulate turbulent, viscous flows over three-dimensional
c configurations. A general multiblock grid approach is used to model
c complex configurations.  A multi-stage Runge-Kutta pseudo-time stepping
c scheme is coupled with residual smoothing and multigrid acceleration
c techniques to form an efficient algorithm for solving transonic viscous
c flows over aerodynamic configurations of practical interest.
c
c The TLNS3D framework is licensed under the Apache License, Version 2.0
c (the "License"); you may not use this application except in compliance
c with the License. You may obtain a copy of the License at
c http://www.apache.org/licenses/LICENSE-2.0. 

c Unless required by applicable law or agreed to in writing, software
c distributed under the License is distributed on an "AS IS" BASIS,
c WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
c See the License for the specific language governing permissions and
c limitations under the License.
c----------------------------------------------------------------------------------------------
c
      subroutine  setpchi(imn,jmn,kmn,mgrlev,mbloc,ngrid,nbloc,
     .            m1pch1,m1pch2,lswpchb,lswpche,
     .            mxtpchc,ntpchcb,npchcbf,
     .            mxpchs,mpchitm,nswpchb,npchitm,lspchb1,lspchf1,
     .            lspchb2,lspchf2,nodes )
c=======================================================================
c 
c
c     object : to read the patcher information from data files generated
c              by a preprocessor and convert this information into
c              a form compatible with tlns3d-mb data structure
c
c              the global patcher information a is read from ipfil1
c              which identifies all the patched cells 
c
c              The information about the source cell and their
c              contribution to conserved variables on the
c              target patched cells is read from ipfil2
c
c     Note   : Currently the files ipfil1 and ipfil2 are
c              generated by Paul Pao and Hamid's preprocessor
c
c     initial coding : by v.n.vatsa, nasa langley ( Sept. 1994)
c     last revision  : low memory version for patching arrays (Feb.1997)
c
c
c---  control parameters on ipfil1, (global patch controller):
c
c        the information on this file is used for detecting and initializing
c        the conserved variables on the cells affected by patch/interface
c        boundary conditions
c
c     ngridp    : no. of mg levels for which global patcher info. follows
c     ntpchcb   : total no. of patched cells on a block (includes all faces)
c     npchcbf   : total no. of cells with patch/interface b.c. on a block face
c                (6 entries, one for each face, 0 if no patched cells on face)
c                (above triplet is repeated to correspond to npchcbf entries)
c
c---  control parameters on ipfil2 :
c
c        this file contains detailed information regarding patch/interface
c        b.c's, such as block, face and cell indices of the source cell,
c        as well as the area weighted influence coefficient needed for
c        computing the contribution of the source cell to the target cell.
c        note that a given target cell may have multiple source cells
c        belonging to different blocks/faces
c
c     ngridpp   : no. of mg levels for which patcher info. follows
c     nswpcht   : total no. of surface segments with patched cells 
c                 at current grid level (includes all blocks)
c                (these patches admit existence  of multiple sources)
c     nswpchb   : no. of surface segments with patched cells on
c                 current block (computed using following info.)
c
c     lswpchb   : starting location of surface segments with patched
c                 cells on current block w.r.t. total no. of 
c                 patched surface segments nswpcht
c
c     lswpche   : ending location of surface segments with patched
c                 cells on current block w.r.t. total no. of 
c                 patched surface segments nswpcht
c
c----     next 5 items are repeated nswpcht times
c
c      npchitm  : no. of source cells (items) contributing to patched
c                 cells on current surface segment
c                (next 5 items are repeated npchitm times)
c      lspchb1  : target (to or block 1) block  identifier
c                 for the patched surface segment
c      lspchf1  : target (to or block 1, face 1) block-face identifier
c                 for the patched surface segment
c      lspchb2  : source (from or block 2) block identifier
c                 for the patched surface segment
c      lspchf2  : source (from or block 2, face 2) block-face identifier
c                  for the patched surface segment
c
c

      dimension   ntpchcb(mbloc,mgrlev), npchcbf(6,mbloc,mgrlev),
     .            m1pch1 (mbloc,mgrlev), m1pch2 (mbloc,mgrlev)
c
c
      dimension nswpchb  (mbloc,mgrlev),   npchitm(mxpchs,mgrlev),
     .          lswpchb  (mbloc,mgrlev),   
     .          lswpche  (mbloc,mgrlev),
     .          lspchb1 (mxpchs,mgrlev),   lspchf1(mxpchs,mgrlev),
     .          lspchb2 (mxpchs,mgrlev),   lspchf2(mxpchs,mgrlev) 
c
      dimension nodes(1)
c
c
      common/files/ iread,iwrit,igrdfil,irstfil,isavfil,ipltfil
     .                   ,imapfil,ipfil1,ipfil2,irhtall,irhtphy
     .                   ,igpfil,iqpfil,idatfil,ipntfil,iavgfil
c
      common/facetr/ ifacetr(6),ipatchg
c
      data ifacetr/3,4,5,6,1,2/
c
c     initialize control parameters for global patches
c
      do 110 igrid=1,ngrid
c
      do 120 ibloc=1,nbloc
c
      ntpchcb(ibloc,igrid)    = 0
      do 125 nf=1,6
      npchcbf(nf,ibloc,igrid) = 0
 125  continue
 120  continue
 110  continue
c
      read (ipfil1,*) ngridp
      if(ngridp.gt.mgrlev.and.ngridp.lt.ngrid) then
        write (iwrit,'(2x,"grid level  conflicts dimensions "/)')
        write (iwrit,'(2x,"ngridp ngrid  mgrlev "/)')
        write (iwrit,'(2x,3i7)') ngridp,ngrid,mgrlev
        write (iwrit,'(2x,"stop in  setpch after statement 110 "/)')
c
        call ERREXIT (nodes)
      endif
c
c     initialize the pointers for patched grids
c
      do igrid=1,ngrid
         do ibloc=1,nbloc
         m1pch1(ibloc,igrid) = 1
         enddo
      enddo
c
c     loop over multigrid levels
c
      lpchcb = 1
      do 1010 igrid=1,ngrid
      read (ipfil1,*) iigrid
      if(iigrid.ne.igrid) then
        write (iwrit,'(2x,"iigrid conflicts with igrid "/)')
        write (iwrit,'(2x,"iigrid igrid  "/)')
        write (iwrit,'(2x,2i7)') iigrid, igrid
        write (iwrit,'(2x,"stop in  setpch after statement 1010 "/)')
c
        call ERREXIT (nodes)
      endif
c
c
c     loop over blocks
c
      do 1020 ibloc=1,nbloc
c
cvn   m1pch1(ibloc,igrid) = lpchcb
c
c
c---read header info as dummy info --
      read (ipfil1,*) 
      read (ipfil1,*) 
      read (ipfil1,*) 
      read (ipfil1,*) 
      read (ipfil1,*) 
      read (ipfil1,*) 
c----------------------------------
      read (ipfil1,*) iblock1
c
      if(iblock1.ne.ibloc) then
        write (iwrit,'(2x,"iblock1 conflicts with ibloc "/)')
        write (iwrit,'(2x,"iblock1 ibloc  "/)')
        write (iwrit,'(2x,2i7)') iblock1, ibloc
        write (iwrit,'(2x,"stop in  setpch after statement 1020 "/)')
c
        call ERREXIT (nodes)
      endif
c
      read (ipfil1,*) idum1,idum2,idum3,idum4,idum5,idum6,idum7,idum8
     .               ,idum9,idum10,idum11,idum12,idum13,idum14,idum15
     .               ,idum16,idum17,idum18,idum19,idum20,idum21
c
      ntpchcb(iblock1,igrid)     = idum1
      npchcbf(1,iblock1,igrid)   = idum10
      npchcbf(2,iblock1,igrid)   = idum11
      npchcbf(3,iblock1,igrid)   = idum12
      npchcbf(4,iblock1,igrid)   = idum13
      npchcbf(5,iblock1,igrid)   = idum14
      npchcbf(6,iblock1,igrid)   = idum15
c
Cc--------
c     note: the face numbering convention used in this subroutine
c           corresponds to the convention used in the pre-processor
c           used for generating the patcher information
c          ( currently we are using Paul Pao & Hamid's convention)
c           The face numbering convention of TLNS3D-MB is recovered
c           through the face-transformation array "ifacetr", which is
c           supplied on top of this routine via data statement.
c---------
c
c     read addresses of patched cells
c
      do 1600 iface=1,6
      if (npchcbf(iface,iblock1,igrid).gt.0) then
c
        lpchce = lpchcb + npchcbf(iface,iblock1,igrid) - 1
c       if (lpchce.gt.mxtpchc) then
c         write (iwrit,'(" lpchce = ",i6," exceeds dimension",
c    .      " of mxtpchc = ",i6," in setpch")') lpchce,mxtpchc
c         call ERREXIT (nodes)
c       endif
c
        do 1030 nn=lpchcb,lpchce
c
        read (ipfil1,*) iidum,jjdum,kkdum
c
c
 1030   continue
c
        lpchcb = lpchce + 1
c
      endif
c
c     end loop over faces
 1600 continue
c
c     end loop over blocks
 1020 continue
c
c     end of grid-level loop
 1010 continue
c
c     this completes the global information required for
c     initializing variables on all patched cells
c     we now start setting up source/target info. for patched cells
c
c     initialize the control parameters for partial-patches
c
      do 210 igrid=1,ngrid
c
      do 220 ibloc=1,nbloc
      m1pch2 (ibloc,igrid)    = 1
c
      nswpchb(ibloc,igrid)    = 0
      lswpchb(ibloc,igrid)    = 0
      lswpche(ibloc,igrid)    = 0
c
 220  continue

      do 225 nn=1,mxpchs
      lspchb1(nn,igrid) = 0
      lspchf1(nn,igrid) = 0
      lspchb2(nn,igrid) = 0
      lspchf2(nn,igrid) = 0
      npchitm(nn,igrid) = 0
 225  continue
c
 210  continue
c
c-----   start reading information from file ipfil2
c
      read (ipfil2,*) ngridpp
      if(ngridpp.gt.mgrlev.and.ngridpp.lt.ngrid) then
        write (iwrit,'(2x,"grid level  conflicts dimensions "/)')
        write (iwrit,'(2x,"ngridpp ngrid  mgrlev "/)')
        write (iwrit,'(2x,3i7)') ngridpp,ngrid,mgrlev
        write (iwrit,'(2x,"stop in  setpch after statement 210 "/)')
c
        call ERREXIT (nodes)
      endif
c
c--   initialize item (patched cell pieces) number
      litmnum = 0
c
c     loop over multigrid levels
c
      do 2010 igrid=1,ngrid
c
      read (ipfil2,*) idum
      if(idum.ne.igrid) then
        write (iwrit,'(2x,"conflict in level  info. on patcher "/)')
        write (iwrit,'(2x,"igridp igrid  "/)')
        write (iwrit,'(2x,2i7)') idum, igrid
        write (iwrit,'(2x,"stop in  setpch after statement 2010 "/)')
c
        call ERREXIT (nodes)
      endif
c
c
      read (ipfil2,*) nswpcht
      if (nswpcht.gt.mxpchs) then
        write (iwrit,'(" nswpcht = ",i6," exceeds dimension",
     .    " of mxpchs = ",i6," in setpch")') nswpcht,mxpchs
        call ERREXIT (nodes) 
      endif
c
      do 2020 nn=1,nswpcht
c
c---read header info as dummy info --
      read (ipfil2,*)
      read (ipfil2,*)
      read (ipfil2,*)
      read (ipfil2,*) iblock1,iface1,iblock2,iface2,nitems
c     if (litmnum+nitems.gt.mpchitm) then
c       write (iwrit,'(" litmnum = ",i6," exceeds dimension",
c    .    " of mpchitm = ",i6," in setpch")')
c    .    litmnum+nitems,mpchitm
c       call ERREXIT (nodes) 
c     endif
      nswpchb(iblock1,igrid) = nswpchb(iblock1,igrid) + 1
      npchitm(nn,igrid)      = nitems
      lspchb1(nn,igrid)      = iblock1
      lspchf1(nn,igrid)      = iface1
      lspchb2(nn,igrid)      = iblock2
      lspchf2(nn,igrid)      = iface2
c
      do 2030 item=1,npchitm(nn,igrid)
c
      read (ipfil2,*) idum1,idum2,idum3,idum4,idum5,idum6,dum
c
      litmnum      = litmnum + 1
c
c
 2030 continue
c
 2020 continue
c
 2010 continue
c
cBWW  the following test replaces the similiar tests that were
cBWW  done in bcflow,bcturb and bcvol previously
c---  lpchs is cumulative value of block/faces with patched b.c.
c---  on current grid level
c
      do 3020 igrid=1,ngrid
      lpchs = 0
      do 3020 ibloc=1,nbloc
      if (ntpchcb(ibloc,igrid).gt.0) then
        lswpchb(ibloc,igrid) = lpchs
        lswpche(ibloc,igrid) = lpchs + nswpchb(ibloc,igrid)
        do 3010 nn=1,nswpchb(ibloc,igrid)
        lpchs  = lpchs + 1
        ibloc1 = lspchb1(lpchs,igrid)
        if (ibloc1.ne.ibloc) then
          write (iwrit,'(2x,"ibloc1 and ibloc are different"/)')
          write (iwrit,'(2x,2i5)') ibloc1, ibloc
          write (iwrit,'(2x,"stop in setpch at end of subroutine"/)')
          call ERREXIT (nodes)
        endif
 3010   continue
      endif
 3020 continue
      return
      end
