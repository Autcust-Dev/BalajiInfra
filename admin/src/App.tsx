import { Navigate, Route, Routes } from 'react-router-dom'
import { ProtectedRoute } from '@/components/auth/ProtectedRoute'
import { StatusGate } from '@/components/auth/StatusGate'
import { AppShell } from '@/components/layout/AppShell'
import { EBillDetailPage } from '@/routes/EBillDetailPage'
import { EBillsPage } from '@/routes/EBillsPage'
import { KycQueuePage } from '@/routes/KycQueuePage'
import { KycReviewPage } from '@/routes/KycReviewPage'
import { LoginPage } from '@/routes/LoginPage'
import { MfaEnrollPage } from '@/routes/MfaEnrollPage'
import { MfaVerifyPage } from '@/routes/MfaVerifyPage'
import { PropertiesPage } from '@/routes/PropertiesPage'
import { PropertyRoomsPage } from '@/routes/PropertyRoomsPage'
import { PropertyStructurePage } from '@/routes/PropertyStructurePage'
import { RentsPage } from '@/routes/RentsPage'
import { TenantFormPage } from '@/routes/TenantFormPage'
import { TenantsPage } from '@/routes/TenantsPage'

function App() {
  return (
    <Routes>
      <Route
        path="/login"
        element={
          <StatusGate when="signed-out">
            <LoginPage />
          </StatusGate>
        }
      />
      <Route
        path="/mfa/enroll"
        element={
          <StatusGate when="mfa-enroll">
            <MfaEnrollPage />
          </StatusGate>
        }
      />
      <Route
        path="/mfa/verify"
        element={
          <StatusGate when="mfa-verify">
            <MfaVerifyPage />
          </StatusGate>
        }
      />

      <Route element={<ProtectedRoute />}>
        <Route element={<AppShell />}>
          <Route index element={<Navigate to="/properties" replace />} />
          <Route path="/properties" element={<PropertiesPage />} />
          <Route path="/properties/:propertyId/rooms" element={<PropertyRoomsPage />} />
          <Route path="/properties/:propertyId/structure" element={<PropertyStructurePage />} />
          <Route path="/tenants" element={<TenantsPage />} />
          <Route path="/tenants/new" element={<TenantFormPage />} />
          <Route path="/tenants/:tenantId/edit" element={<TenantFormPage />} />
          <Route path="/kyc" element={<KycQueuePage />} />
          <Route path="/kyc/:submissionId" element={<KycReviewPage />} />
          <Route path="/ebills" element={<EBillsPage />} />
          <Route path="/ebills/:billId" element={<EBillDetailPage />} />
          <Route path="/rents" element={<RentsPage />} />
        </Route>
      </Route>
    </Routes>
  )
}

export default App
